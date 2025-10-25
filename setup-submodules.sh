#!/bin/bash

# Script to set up Git submodules for Vinylhound project
set -e

echo "Setting up Git submodules for Vinylhound..."

# Initialize Backend submodule
git submodule add https://github.com/jessig1/vinylhound-backend.git Vinylhound-Backend
git config -f .gitmodules submodule.Vinylhound-Backend.branch main

# Initialize Frontend submodule
git submodule add https://github.com/jessig1/vinylhound-frontend.git vinylhound-frontend
git config -f .gitmodules submodule.vinylhound-frontend.branch main

# Initialize Infrastructure submodule
git submodule add https://github.com/jessig1/vinylhound-infrastructure.git Vinylhound-Infrastructure
git config -f .gitmodules submodule.Vinylhound-Infrastructure.branch main

# Initialize and update all submodules
git submodule update --init --recursive

echo "Submodules have been set up successfully!"
echo "To clone this repository in the future, use:"
echo "git clone --recursive https://github.com/jessig1/vinylhound.git"
echo ""
echo "To update all submodules to their latest versions, use:"
echo "git submodule update --remote --merge"