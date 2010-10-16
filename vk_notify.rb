#!/usr/bin/env ruby

# == Synopsis
#   simple command line utility for sending
#   a message to all application's users
#
# == Usage
#   vk_notify.rb [OPTIONS]
#
#   --help, -h:
#     this help
#
#   --users, -u:
#     users file
#
#   --message, -m:
#     message to send
#
#   --app, -a:
#     app name
#
# == Config
#   configuration lives in ~/.vk_apps
#   it's a yaml file with following structure
#
#     app_name:
#       api_id: 123
#       api_secret: foo
#
# == Author
#   Viktor Kotseruba <barbuza@me.com>
#
# == Copyright
#   Copyright (c) 2010 Beenza Games


require "yaml"
require "getoptlong"
require "rdoc/usage"
require "md5"
require "net/http"
require "uri"
require "json"


API_URL = "http://api.vkontakte.ru/api.php"
API_VERSION = "3.0"
METHOD = "secure.sendNotification"
CHUNK_SIZE = 100

API_URI = URI.parse(API_URL)


class VkNotify

  def run
    parse_arguments
    load_vk_apps
    load_app_config
    parse_users_file
    send_message
  end

  private

  def load_app_config
    @app_config = @vk_apps[@app_name]
    throw "app not found" unless @app_config
    @api_id = @app_config["api_id"]
    throw "api_id not specified" unless @api_id
    @api_secret = @app_config["api_secret"]
    throw "api_secret not specified" unless @api_secret
  end

  def load_vk_apps
    @vk_apps = YAML.load_file File.expand_path("~/.vk_apps")
  end

  def parse_users_file
    @users = []
    file = File.new @users_file
    while line = file.gets
      @users.push line.to_i if line.to_i > 0
    end
    file.close
    @users.uniq!
  end

  def parse_arguments
    opts = GetoptLong.new(
      ["--help", "-h", GetoptLong::NO_ARGUMENT],
      ["--users", "-u", GetoptLong::REQUIRED_ARGUMENT],
      ["--message", "-m", GetoptLong::REQUIRED_ARGUMENT],
      ["--app", "-a", GetoptLong::REQUIRED_ARGUMENT]
    )
    opts.each do |opt, arg|
      case opt
      when "--help"
        RDoc::usage
      when "--users"
        @users_file = arg
      when "--message"
        @message = arg
      when "--app"
        @app_name = arg
      end
    end
    RDoc::usage unless @message && @users_file && @app_name
  end

  def send_message
    @http = Net::HTTP.new(API_URI.host, API_URI.port)
    total = @users.size
    complete = 0
    until @users.empty?
      uids = @users.slice!(0, CHUNK_SIZE)
      send_message_to uids
      if total > complete + CHUNK_SIZE
        complete += CHUNK_SIZE
      else
        complete = total
      end
      display_progress complete, total
    end
  end

  def display_progress(complete, total)
    puts "complete #{(100.0 * complete / total).ceil}% (#{complete} of #{total})"
  end

  def send_message_to(uids)
    params = get_params_for uids
    query = params.map{ |key, value|
      "#{CGI::escape(key)}=#{CGI::escape(value.to_s)}"
    } * "&"
    http_response = @http.get("#{API_URI.path}?#{query}")
    response = JSON.parse(http_response.body)
    if response.include? "error"
      if response["error"]["error_code"] == 6
        sleep 0.5
        send_message_to uids
      else
        throw response["error"]["error_msg"]
      end
    end
  end

  def get_params_for(uids)
    params = {
      "method" => METHOD,
      "api_id" => @app_config["api_id"],
      "v" => API_VERSION,
      "format" => "JSON",
      "timestamp" => Time.now.to_i,
      "random" => ((1 << 32) * rand).ceil,
      "uids" => uids * ",",
      "message" => @message
    }
    sign_params! params
    params
  end

  def sign_params!(params)
    sig_string = ""
    params.sort.each do |key, val|
      sig_string += "#{key}=#{val}"
    end
    sig_string += @app_config["api_secret"]
    params["sig"] = MD5.new(sig_string).hexdigest
  end

end


app = VkNotify.new
app.run
