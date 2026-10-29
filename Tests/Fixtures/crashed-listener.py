#!/usr/bin/python3
"""Synthetic crashed Unix listener, isolated test directory only."""
import fcntl
import os
import socket
import sys

directory = sys.argv[1]
os.mkdir(directory, 0o700)
lock = os.open(directory + '/listener.lock', os.O_CREAT | os.O_RDWR, 0o600)
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
listener.bind(directory + '/events.sock')
os.chmod(directory + '/events.sock', 0o600)
listener.listen(8)
# Bypass all cleanup, leaving the socket inode and lock file behind. The OS
# releases the listener and flock exactly as on an ungraceful app exit.
os._exit(0)
