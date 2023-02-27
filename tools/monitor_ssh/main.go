package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	log "github.com/sirupsen/logrus"
	"github.com/yanzay/tbot/v2"
	"golang.org/x/crypto/ssh"
)

// set during compilation using ldflags
var Version string
var Buildtime string

// stores `server:secret` from -s flag
var servers = map[string]string{}

// flags
var timerFlag = flag.Duration("timer", time.Minute, "how often to connect to segfault servers")
var versionFlag = flag.Bool("version", false, "print program version")
var debugFlag = flag.Bool("debug", false, "print debug logs")

func init() {

	flag.Func("s", "server:secret", func(s string) error {

		split := strings.Split(s, ":")
		if len(split) < 2 {
			return fmt.Errorf("must provide server:secret")
		}
		servers[split[0]] = split[1]
		return nil
	})
	flag.Parse()

	log.SetFormatter(&log.TextFormatter{
		ForceColors: true,
	})

	if *debugFlag {
		log.SetLevel(log.DebugLevel)
		log.SetReportCaller(true)
	}
}

var (
	// telegram bot secret key
	tgKEY = mustEnv("TG_KEY")
	// telegram chat id
	tgCHATID = mustEnv("TG_CHATID")
)

func main() {

	if *versionFlag {
		fmt.Printf("%v compiled on %v from commit %v\n", os.Args[0], Buildtime, Version)
		os.Exit(0)
	}

	log.Debugf("Telegram chat ID: %v", tgCHATID)
	bot := tbot.New(tgKEY)
	bot.HandleMessage("cowsay .+", func(m *tbot.Message) {
		// we use cowsay to confirm supergroup chat ids
		log.Printf("chat id: %v", m.Chat.ID)

		text := strings.TrimPrefix(m.Text, "cowsay ")
		cow := fmt.Sprintf("```\n%s\n```", cowsay(text))
		bot.Client().SendMessage(m.Chat.ID, cow, tbot.OptParseModeMarkdown)
	})
	go func() { // run bot listener on his own thread
		err := bot.Start()
		if err != nil {
			log.Fatal(err)
		}
	}()

	// collects errors and sends them as message via telegram bot
	var msgC = make(chan string, len(servers)) // buffered
	defer close(msgC)
	go func() {
		for msg := range msgC {
			log.Warnf("%v", msg)
			_, err := bot.Client().SendMessage(tgCHATID, msg)
			if err != nil {
				log.Errorf("%v: %+v", err, "bah")
				continue
			}
		}
		log.Debugf("exiting...")
	}()

	var (
		wg = &sync.WaitGroup{}

		// protects `connTracker` from concurrent r/w.
		mu          sync.Mutex
		connTracker int
	)

	// keeps track of a server down time.
	var downTime = map[string]time.Time{}
	// program main loop.
	var badState = map[string]string{}
	for {
		for server, secret := range servers {

			wg.Add(1)
			go func(server, secret string) {
				defer func() {
					wg.Done()
					mu.Lock()
					connTracker++
					mu.Unlock()
				}()

				err := checkServer(server, secret)
				if err != nil {
					if badState[server] == err.Error() {
						log.Debugf("%v has already been reported")
						return
					}
					log.Debug(err)
					msgC <- err.Error()
					badState[server] = err.Error()
					downTime[server] = time.Now().UTC()
				} else {
					if _, ok := badState[server]; ok {
						elapsed := time.Since(downTime[server])
						msgC <- fmt.Sprintf("[%v] is now healthy [down %v]", server, elapsed.String())
						delete(badState, server)
						delete(downTime, server)
					}
				}
			}(server, secret)
		}

		log.Debug("waiting for routines to return")
		wg.Wait()

		time.Sleep(*timerFlag)

		mu.Lock()
		log.Infof("[#%v] successful connections", connTracker)
		mu.Unlock()
	}
}

var SSH_CLIENT_CONF = &ssh.ClientConfig{
	Timeout:         time.Second * 5,
	ClientVersion:   "SSH-2.0-Segfault",
	User:            "root",
	Auth:            []ssh.AuthMethod{ssh.Password("segfault")},
	HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	BannerCallback: func(message string) error {
		return nil
	},
}

func checkServer(server, secret string) error {
	const SSH_PORT = "22"

	client, err := ssh.Dial("tcp", server+":"+SSH_PORT, SSH_CLIENT_CONF)
	if err != nil {
		return fmt.Errorf("[%v] connection failed: %v", server, err)
	}
	defer client.Close()

	session, err := client.NewSession()
	if err != nil {
		return fmt.Errorf("[%v] SSH session failed: %v", server, err)
	}
	defer session.Close()
	session.Setenv("SECRET", secret)

	// configure terminal mode
	modes := ssh.TerminalModes{
		ssh.ECHO: 0, // supress echo
	}
	// run terminal session
	if err := session.RequestPty("xterm", 50, 80, modes); err != nil {
		return fmt.Errorf("[%v] SSH request PTY failed: %v", server, err)
	}

	out, err := session.CombinedOutput("uptime 2>&1")
	if err != nil {
		return fmt.Errorf("[%v] SSH `uptime` command failed: %v", server, err)
	}

	log.Infof("[%v] %v", server, string(out))
	return nil
}

// mustEnv panics if our required envs are not present.
func mustEnv(s string) string {
	env := os.Getenv(s)
	if env == "" {
		log.Fatalf("must provide environment variable: `export %v=`", s)
	}
	return env
}

// for fun.
func cowsay(text string) string {
	lineLen := utf8.RuneCountInString(text) + 2
	topLine := fmt.Sprintf(" %s ", strings.Repeat("_", lineLen))
	textLine := fmt.Sprintf("< %s >", text)
	bottomLine := fmt.Sprintf(" %s ", strings.Repeat("-", lineLen))
	cow := `
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
               ||----w |
               ||     ||
	`
	resp := fmt.Sprintf("%s\n%s\n%s%s", topLine, textLine, bottomLine, cow)
	return resp
}
