require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'net/http'
require 'net/https'
require 'json'
require 'date'

configure do
  set :dbapikey, "0ece318cccdac2ae2c6a94a66690480a"
  # please replace this with your own douban api key
  set :nickname, "AquarHEAD L."
end

DataMapper::setup(:default, "mysql://asreader:asreader@localhost/asreader")

class Excerpt
  include DataMapper::Resource

  property :id, Serial
  property :content, Text
  property :page, String
  property :created_at, DateTime

  belongs_to :book
end

class Book
  include DataMapper::Resource

  property :id, Serial
  property :douban_id, String
  property :url, URI
  property :title, String
  property :status, Enum[ :wish, :reading, :finished, :holding, :dropped, :reference]
  property :rating, Integer
  property :note, Text
  property :note_updated, DateTime
  property :started_at, DateTime
  property :ended_at, DateTime

  has n, :excerpts
end

DataMapper.finalize

DataMapper.auto_upgrade!

set :public_folder, File.dirname(__FILE__) + '/static'

get '/' do
  erb :index, :locals => {nick: settings.nickname}
end

get '/books' do
  wish = Book.all(:status => :wish)
  reading = Book.all(:status => :reading)
  finished = Book.all(:status => :finished)
  holding = Book.all(:status => :holding)
  dropped = Book.all(:status => :dropped)
  reference = Book.all(:status => :reference)
  erb :books, :locals => {nick: settings.nickname, wish: wish, reading: reading, finished: finished, holding: holding, dropped: dropped, reference: reference}
end

get '/import-douban/:db_user' do

  uri = URI.parse("https://api.douban.com/")
  request = Net::HTTP.new(uri.host, uri.port)
  request.use_ssl = true

  # Add reading books
  start = 0
  begin
    resp = request.get("/v2/book/user/#{params[:db_user]}/collections?status=reading&start=#{start}&count=100&apikey=#{settings.dbapikey}")
    reading_data = JSON.parse(resp.body)
    reading_data["collections"].each do |b|
      bk = Book.new
      bk.douban_id = b["book"]["id"]
      bk.url = b["book"]["alt"]
      bk.title = b["book"]["title"]
      bk.status = :reading
      bk.started_at = DateTime.parse(b["updated"])
      if b.has_key? "rating"
        bk.rating = b["rating"]["value"].to_i * 2
      end
      bk.save
    end
    start += 100
  end until start >= reading_data["total"]

  # Add finished books
  start = 0
  begin
    resp = request.get("/v2/book/user/#{params[:db_user]}/collections?status=read&start=#{start}&count=100&apikey=#{settings.dbapikey}")
    read_data = JSON.parse(resp.body)
    read_data["collections"].each do |b|
      bk = Book.new
      bk.douban_id = b["book"]["id"]
      bk.url = b["book"]["alt"]
      bk.title = b["book"]["title"]
      bk.status = :finished
      bk.ended_at = DateTime.parse(b["updated"])
      if b.has_key? "rating"
        bk.rating = b["rating"]["value"].to_i * 2
      end
      bk.save
    end
    start += 100
  end until start >= read_data["total"]

  # Add wish books
  start = 0
  begin
    resp = request.get("/v2/book/user/#{params[:db_user]}/collections?status=wish&start=#{start}&count=100&apikey=#{settings.dbapikey}")
    wish_data = JSON.parse(resp.body)
    wish_data["collections"].each do |b|
      bk = Book.new
      bk.douban_id = b["book"]["id"]
      bk.url = b["book"]["alt"]
      bk.title = b["book"]["title"]
      bk.status = :wish
      if b.has_key? "rating"
        bk.rating = b["rating"]["value"].to_i * 2
      end
      bk.save
    end
    start += 100
  end until start >= wish_data["total"]

  "Finished."
end
