# Running on Apple Silicon (ARM64)
Rosetta is now Generally Available for all users on macOS 13 or later. It provides faster emulation of Intel-based images on Apple Silicon (M1 & M2...). To use Rosetta, see Settings. Rosetta is enabled by default on macOS 14.1 and later.

if having trouble emulating x86 images try installing rosetta via the terminal using 
  > softwareupdate --install-rosetta

and enabling the following settings in docker desktop (version 4.16.1 or greater) under
  > Settings > General > Use Virtualization framework

  > Settings > General >
  Use Rosetta for x86_64/amd64 emulation on Apple Silicon

[Back to readme](../README.md)