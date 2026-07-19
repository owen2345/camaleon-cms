#!/bin/bash
set -e

echo "=== Running Zeitwerk check ==="
(cd spec/dummy && bin/rails zeitwerk:check)

echo ""
echo "=== Running model specs ==="
bin/rspec spec/models