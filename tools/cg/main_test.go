package main

import (
	"os"
	"testing"
)

func TestSanitize(t *testing.T) {
	from := "/dev/urandom"
	file, err := os.Open(from)
	if err != nil {
		t.Fatalf("unable to open file %v", err)
	}
	defer file.Close()

	data := make([]byte, 4096)
	n, err := file.Read(data)
	if err != nil {
		t.Fatalf("unable to read bytes: %v", err)
	}

	t.Logf("read %v bytes from %v", n, from)
	r1 := sanitize(string(data))
	t.Logf("result1: %v", r1)
}
