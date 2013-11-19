#!/usr/bin/env ruby

$: << "."
require 'mailer'
require 'sites'

eta = WebDiff::Site::ETA.new
had = WebDiff::Site::Hackaday.new
