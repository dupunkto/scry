#!/usr/bin/env bash

set -eu

HOST="${HOST:-http://localhost:4000}"

track() {
  curl -fsS -X POST "$HOST/api/track/$1" \
    --data-urlencode "source_code=$2" \
    --data-urlencode "token=$TOKEN" > /dev/null
  echo "tracked $1"
}

squash() {
  curl -fsS -X POST "$HOST/api/squash/$1" \
    --data-urlencode "message=$2" \
    --data-urlencode "token=$TOKEN" > /dev/null
  echo "squashed $1: $2"
}

# hello.ex -- three revisions, no pending edits.
track hello.ex 'IO.puts "hello"'
squash hello.ex "Initial version"

track hello.ex 'IO.puts "Hello, world!"'
squash hello.ex "Capitalize and add comma"

track hello.ex 'IO.puts("Hello, world!")'
squash hello.ex "Use explicit parens"

# greeter.py -- one revision, then a couple of pending edits.
track greeter.py 'print("Hi")'
squash greeter.py "First draft"

track greeter.py 'print("Hi there")'
track greeter.py 'print("Hi there!")'

# notes.md -- pending edits only, never squashed into a revision.
track notes.md '# Notes

Just dumping thoughts.'

track notes.md '# Notes

Just dumping thoughts. More to follow.'
