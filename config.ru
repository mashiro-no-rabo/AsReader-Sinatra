# encoding: utf-8

require 'rubygems'
require 'sinatra'

set :environment, :development
disable :run, :reload

require './app'
run Sinatra::Application
