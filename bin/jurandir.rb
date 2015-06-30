#!/usr/bin/ruby

$: << File.expand_path('../lib')

require 'optparse'
require 'colorize'
require 'jurandir'

Jurandir::Application.run
