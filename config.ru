require 'rubygems'
require 'sinatra'
require File.expand_path 'mutating_webhook.rb', __dir__

run Sinatra::Application
