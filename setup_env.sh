#!/usr/bin/env bash

# https://learn.microsoft.com/en-us/azure/developer/python/get-started?tabs=cmd#phase-2-configure-your-local-python-environment-for-azure-development
# apt install python3-venv python3-pip

PYTHON_EXE=/usr/bin/python3
VENV_NAME=".venv"

$PYTHON_EXE -m venv $VENV_NAME
source $VENV_NAME/bin/activate
$PYTHON_EXE -m pip install -r requirements.txt

# deactivate
