#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCKET_PATH "/dev/shm/sf/run/logpipe/logPipe.sock"

int main(int argc, char *argv[]) {
    int sockfd;
    struct sockaddr_un addr;

    sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sockfd == -1) {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    memset(&addr, 0, sizeof(struct sockaddr_un));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(sockfd, (struct sockaddr *)&addr, sizeof(struct sockaddr_un)) == -1) {
        perror("connect");
        exit(EXIT_FAILURE);
    }

    char buf[1024];
    ssize_t nread;
    while ((nread = read(STDIN_FILENO, buf, sizeof(buf))) > 0) {
        if (write(sockfd, buf, nread) != nread) {
            perror("write");
            exit(EXIT_FAILURE);
        }
    }

    if (nread == -1) {
        perror("read");
        exit(EXIT_FAILURE);
    }

    close(sockfd);
    return EXIT_SUCCESS;
}