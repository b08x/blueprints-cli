# frozen_string_literal: true

require "sinatra/base"

class MyApp < Sinatra::Base
  get "/" do
    "Hello Falcon!"
  end
end
