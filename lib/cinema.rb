require "cinema/version"
require 'tempfile'
require 'traktr'
require 'yify'
require 'yaml'

module Cinema
  class << self
    def ask_and_play
      imdb_id = select("Select movie", watchlist, ->(x){ x["title"] })["imdb_id"]
      torrent = select("Select quality", torrents(imdb_id), ->(x){ x.quality })["torrent_url"]
      player = select("Select player", ["mplayer","vlc"], ->(x){x})
      with_unreliable_api do
        raise unless system "peerflix", torrent, "--#{player}"
      end
    end

    def select(title, items, title_proc)
      menu_items = items.each_with_index.map{|x,i| [i.to_s, title_proc.(x)]}
      index = capture_stderr do
        system 'dialog', '--title', title,
          '--menu', '', '0', '0', '0',
          *menu_items.flatten
      end.to_i
      items[index]
    end

    def watchlist
      with_unreliable_api do
        puts "Requesting watchlist..."
        trakt.user.watchlist.movies
      end
    end

    def torrents(imdb_id)
      with_unreliable_api do
        puts "Searching torrents..."
        yify.list_imdb(imdb_id: imdb_id).result
      end
    end

    def yify
      @yify ||= Yify::Client.new
    end

    def trakt
      @trakt ||= Traktr::Client.new config['api_key'], config['username'], config['password']
    end

    def config
      @config ||= if File.exist? config_file
                    YAML.load_file config_file
                  else
                    STDERR.puts "#{config_file} not found"
                    exit 255
                  end
    end

    def config_file
      "#{ENV['HOME']}/.config/cinema.yml"
    end

    def with_unreliable_api(delay=3)
      begin
        yield
      rescue
        puts "Request failed. Retrying in #{delay} seconds..."
        sleep delay
        retry
      end
    end

    def capture_stderr
      backup_stderr = STDERR.dup
      begin
        Tempfile.open("captured_stderr") do |f|
          STDERR.reopen(f)
          yield
          f.rewind
          f.read
        end
      ensure
        STDERR.reopen backup_stderr
      end
    end
  end
end
