#!/bin/bash

# Artix does not currently package the linux-t2 stack or a maintained t2fanrd
# dinit service. Do not attempt a partial install that leaves T2 Mac hardware
# unusable; see docs/dinit-compatibility.md for the restoration condition.
:
