# Set shell for all recipes
set shell := ["bash", "-c"]

# Default recipe: show all available recipes
default:
    @just --list

# Format all Julia code using Runic
format:
    julia --startup-file=no --project=.format -e 'import Pkg; Pkg.instantiate()'
    julia --startup-file=no --project=.format .format/format.jl
