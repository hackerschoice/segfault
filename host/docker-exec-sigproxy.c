// The problem is that 'docker exec' does not proxy signals to the instance.
// 'docker run' does (--sig-proxy=true is the default)
//
// The consequence of this is that any SIGHUP/SIGINT/SIGTERM to docker-cli
// will keep the process inside the instance running.
//
// Details:
// - https://github.com/moby/moby/issues/9098#issuecomment-702524998
// - https://gist.github.com/SkyperTHC/cb4ebb633890ac36ad86e80c6c7a9bb2
//
// This tool solves this problem and proxies the signal.
//
// gcc -Wall -O2 -o docker-exec-sigproxy docker-exec-sigproxy.c
// Example:
//    ./docker-exec-sigproxy exec -it alpine
// Any signal that is send to 'docker-exec-sigproxy' is forwarded ash.
//
// This problem kicked our butts at thc.org/segfault. We spawn user shells using
// 'docker exec'. When sshd detects a network error it sends a SIGHUP to 'docker exec'.
// It does not forward the signal to the started instance (to 'ash'). 
// Thus we ended up with hundrets of stale 'ash -il' shells that were not
// connected to any sshd.
//
// This hack solves the problem by intercepting the traffic between the docker sockets,
// extracting container id and exec-id and then hocking all signals and forwarding them
// correctly to the instance.
//
// In our setup the docker-cli is executed by sshd from within another
// docker instance. Thus we need to 'break out' of that instance to get access
// to the host's pid system and to find out the host-pid of the ash process.
// If you do not do this then comment out "SIGPROXY_INSIDE_CONTAINER"....
//
// Notes to compile for our needs (not relevant to anyone else):
// docker run --name alpine-gcc -it alpine
//     apk update && apk add gcc libc-dev && exit
// docker commit alpine-gcc alpine-gcc
// docker run --rm -v$(pwd):/src -w /src -it alpine-gcc sh -c "gcc -Wall -O2 -o fs-root/bin/docker-exec-sigproxy docker-exec-sigproxy.c"
// And we then ship the compiled binary inside our image.

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <sys/un.h>
#include <sys/epoll.h>
#include <signal.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>

#define DFL_DOCKER_SOCK   "/var/run/docker.sock"
#define DFL_PROXY_SOCK    "/dev/shm/dproxy-%d.sock"
#define DFL_CONTAINER_DIR "/var/run/containerd/io.containerd.runtime.v2.task/moby"
// Comment this line if 'docker-exec-sigproxy exec ...' is run from the HOST 
#define SIGPROXY_INSIDE_CONTAINER   (1)

//#define DEBUG (1)
FILE *dout;
#ifdef DEBUG
# define DEBUGF(a...) do{fprintf(dout, "\033[0;33mDEBUG\033[0m %s:%d ", __func__, __LINE__); fprintf(dout, a); fflush(dout);}while(0)
#else
# define DEBUGF(a...) do{}while(0)
#endif

static pid_t pid;
static int lsox;
static int efd;
static struct sockaddr_un addr;
static char *container_id;
static char *exec_id;
static char sock_path[1024];

void
docker_exec(int argc, char *argv[])
{
	pid = fork();

	if (pid != 0)
	{
		// HERE: Parent.
		// Close STDIN. Child takes over STDIN and docker does his stty-raw thingie
		close(0);
		close(1);
		if (dout != stderr)
			close(2);
		return;
	}

	// HERE: Child.
	// Become session leader so that any signal does not reach real docker.
	// This gives us time to retrieve the PID before it dies..
	// Once we proxied all pids then we shall forward the signal to this child.
	setsid();
	char buf[1024];
	snprintf(buf, sizeof buf, "DOCKER_HOST=unix://%.900s", sock_path);
	putenv(buf);
	argv[0] = "docker";
	execvp(argv[0], argv);
	exit(255);
}

struct _peer
{
	int fd;
	int flags;
	void *buddy;
};

// Add an event to wake if there is something to read on fd.
void
ev_peer_add(struct _peer *p, int fd, int flags)
{
	p->fd = fd;
	p->flags = flags;
	struct epoll_event ev;

	memset(&ev, 0, sizeof ev);
	ev.events = EPOLLIN;
	ev.data.ptr = p;
	epoll_ctl(efd, EPOLL_CTL_ADD, fd, &ev);
}

// Relay between these two peers.
static void
buddy_up(int in, int out)
{
	struct _peer *p = malloc(sizeof *p);
	struct _peer *buddy;

	ev_peer_add(p, in, 1);

	p->buddy = malloc(sizeof *p);
	buddy = p->buddy;
	buddy->buddy = p;

	ev_peer_add(buddy, out, 0);
}

// New incoming connection.
// 1. Connect to real socket
// 2. Relay traffic between the two sockets.
void
ev_accept(void)
{
	int in;
	int out;

	DEBUGF("Accept\n");
	in = accept(lsox, NULL, NULL);
	if (in < 0)
		exit(255);

	// Connect to original socket.
	out = socket(AF_UNIX, SOCK_STREAM| SOCK_CLOEXEC, 0);
	if (connect(out, (struct sockaddr *)&addr, sizeof addr) != 0)
		exit(254);

	buddy_up(in, out);
}

// Dirty: First ID we get is container. Second is exec_id.
static void
parse(char *buf, ssize_t sz)
{
	char *ptr;
	char *next;

	ptr = strstr(buf, "{\"Id\":\"");
	if (ptr == NULL)
		return;

	ptr += 7;
	next = strchr(ptr, '"');
	if (next == NULL)
		return;
	*next = '\0';

	if (container_id == NULL)
		container_id = strdup(ptr);
	else if (exec_id == NULL)
		exec_id = strdup(ptr);
}

int
dispatch(struct epoll_event *evs, int count)
{
	struct epoll_event *e;
	int n;
	ssize_t sz;
	char buf[4096];

	// Relay data between both sockets.
	for (n = 0; n < count; n++)
	{
		e = &evs[n];
		if (e->data.fd == lsox)
		{
			ev_accept();
			continue;
		}

		if (e->events & EPOLLIN)
		{
			struct _peer *p = e->data.ptr;
			struct _peer *buddy = p->buddy;
			sz = read(p->fd, buf, sizeof buf - 1);
			if (sz <= 0)
				return -1;
			buf[sz] = '\0';
			// DEBUGF("read(%d)=%zd '%s'\n", p->fd, sz, buf);
			if (write(buddy->fd, buf, sz) != sz)
				return -1;
			if ((exec_id == NULL) && (p->flags == 0))
			{
				parse(buf, sz);
			}
		}
	}

	return 0;
}

static void
cb_signal(int sig)
{
	DEBUGF("SIGNAL %d\n", sig);
	if (sig == SIGCHLD)
	{
		int wstatus = 0;
		// The child died. Exit the same way.
		if (waitpid(pid, &wstatus, 0) == pid)
		{
			if (WIFEXITED(wstatus))
				exit(WEXITSTATUS(wstatus));

			signal(WTERMSIG(wstatus), SIG_DFL);
			// Kill myself with the same signal.
			kill(getpid(), WTERMSIG(wstatus));
		}
		exit(255); // SHOULD NOT HAPPEN
	}

	// Forward signal to exec'ed pid.
	char cmd[4096];

#ifdef SIGPROXY_INSIDE_CONTAINER
	// NOTE: This docker-cli is inside a docker already. Thus we need to break out:
	snprintf(cmd, sizeof cmd, "docker run --rm --pid=host -v "DFL_CONTAINER_DIR"/%s/%s.pid:/pid alpine sh -c 'kill -%d $(cat /pid)'", container_id, exec_id, sig);
#else
	snprintf(cmd, sizeof cmd, "kill -%d $(cat "DFL_CONTAINER_DIR"/%s/%s.pid:)", container_id, exec_id, sig);
#endif
	system(cmd);

	// Forward signal to child.
	if (pid > 0)
		kill(pid, sig);
}

static struct termios tios;
static int tios_error = -1;

static void
do_exit()
{
	unlink(sock_path);
	if (tios_error == 0)
		tcsetattr(STDIN_FILENO, TCSADRAIN, &tios);
}

int
main(int argc, char *argv[])
{
#ifdef DEBUG
	char *ptr = getenv("SF_LOG");
	if (ptr != NULL)
		dout = fopen(ptr, "w");
	if (dout == NULL)
		dout = stderr;
#endif

	tios_error = tcgetattr(STDIN_FILENO, &tios);

	// Catch all signals...
	int n;
	for (n = 1; n < 64; n++)
		signal(n, cb_signal);

	// signal(SIGINT, cb_signal);
	// signal(SIGHUP, cb_signal);
	// signal(SIGTERM, cb_signal);

	atexit(do_exit);
	// Create listening socket
	lsox = socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0);

	addr.sun_family = AF_UNIX;
	snprintf(sock_path, sizeof sock_path, DFL_PROXY_SOCK, getpid());
	snprintf(addr.sun_path, sizeof addr.sun_path, "%.107s", sock_path);

	bind(lsox, (struct sockaddr *)&addr, sizeof addr);
	listen(lsox, 5);
	snprintf(addr.sun_path, sizeof addr.sun_path, DFL_DOCKER_SOCK);

	// Start the original docker client
	docker_exec(argc, argv);

	efd = epoll_create1(EPOLL_CLOEXEC);

	// Event for the listening socket...
	struct epoll_event ev;
	ev.events = EPOLLIN;
	ev.data.fd = lsox;
	epoll_ctl(efd, EPOLL_CTL_ADD, lsox, &ev);

	int nfds;
	struct epoll_event events[4];
	for (;;)
	{
		nfds = epoll_wait(efd, events, 4, -1);
		if (nfds < 0)
		{
			if (errno == EINTR)
				continue;
			break;
		}
		if (dispatch(events, nfds) != 0)
			break;
	}

	return 0;
}
