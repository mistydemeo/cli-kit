# typed: true
# frozen_string_literal: true

require 'English'
require 'bundler/setup'
require 'byebug'
require 'cli/kit'
require 'cli/kit/sorbet_runtime_stub'
require 'cli/kit/version'
require 'cli/ui'
require 'cli/ui/version'
require 'fileutils'
require 'minitest/autorun'
require 'minitest/unit'
require 'mocha/minitest'
require 'open3'
require 'pathname'
require 'rubygems'
require 'simplecov'
require 'tempfile'
require 'tmpdir'