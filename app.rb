# encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'net/http'
require 'net/https'
require 'json'
require 'date'
require 'dm-aggregates'
require 'rdiscount'

configure do
  set :dbapikey, "0ece318cccdac2ae2c6a94a66690480a"
  # please replace this with your own douban api key
  set :nickname, "AquarHEAD L."
  # and your own nickname :D
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
  property :douban_id, String, :unique => true
  property :url, URI
  property :title, String
  property :status, Enum[ :wish, :reading, :finished, :holding, :dropped, :reference]
  property :rating, Integer
  property :note, Text
  property :note_updated, DateTime
  property :started_at, DateTime
  property :ended_at, DateTime
  property :updated, DateTime

  has n, :excerpts
end

DataMapper.finalize

DataMapper.auto_upgrade!

before do
  @nick = settings.nickname
  @stats = {
    reference: { title: "Reference", sub: "As dictionaries", icon: "random" },
    reading: { title: "Reading", sub: "To upgrade myself", icon: "book" },
    holding: { title: "Holding", sub: "For a later time", icon: "lock" },
    wish: { title: "Wish", sub: "Human knowledge", icon: "bookmark" },
    finished: { title: "Read", sub: "In the past", icon: "ok" },
    dropped: { title: "Dropped", sub: "Just personally", icon: "remove" }
  }
  @stats_array = @stats.keys
  @rating_str = [
    "天雷",
    "巨雷",
    "雷",
    "较雷",
    "不过不失",
    "还行",
    "推荐",
    "力荐",
    "神作",
    "超神作"
  ]
  @colors = [
    "#F3F781",
    "#CED8F6"
  ]
end

get '/' do
  @exp = Excerpt.all.sample
  @books = Book.all( :order => [ :updated.desc ] )
  haml :index
end

get '/books/?' do
  @books = Book.all
  haml :books
end

get '/book/:book_id/change_status/:status/?' do
  bk = Book.get(params[:book_id])
  bk.status = params[:status].intern
  bk.updated = DateTime.now
  bk.save
  redirect back
end

get '/book/:book_id/rate/:rating/?' do
  bk = Book.get(params[:book_id])
  bk.rating = params[:rating].to_i
  if bk.rating < 1
    bk.rating = 1
  end
  if bk.rating > @rating_str.length
    bk.rating = @rating_str.length
  end
  bk.updated = DateTime.now
  bk.save
  redirect back
end

get '/book/:book_id/?' do
  @book = Book.get(params[:book_id])
  @nc_stats = @stats.dup.delete_if { |k, v| k == @book.status }
  haml :detail
end

post '/book/:book_id/excerpt/?' do
  @book = Book.get(params[:book_id])
  exp = Excerpt.new
  exp.book = @book
  exp.content = params[:content]
  exp.page = params[:page]
  exp.save
  @book.updated = DateTime.now
  @book.save
  redirect back
end

get '/import-douban/:db_user/?' do

  uri = URI.parse("https://api.douban.com/")
  request = Net::HTTP.new(uri.host, uri.port)
  request.use_ssl = true

  # Add reading books
  start = 0
  begin
    resp = request.get("/v2/book/user/#{params[:db_user]}/collections?start=#{start}&count=100&apikey=#{settings.dbapikey}")
    data = JSON.parse(resp.body)
    data["collections"].each do |b|
      bk = Book.new
      bk.douban_id = b["book"]["id"]
      bk.url = b["book"]["alt"]
      bk.title = b["book"]["title"]
      if b["status"] == "reading"
        bk.status = :reading
        bk.started_at = DateTime.parse(b["updated"])
      elsif b["status"] == "read"
        bk.status = :finished
        bk.ended_at = DateTime.parse(b["updated"])
      else
        bk.status = :wish
      end
      bk.updated = DateTime.parse(b["updated"])
      if b.has_key? "rating"
        bk.rating = b["rating"]["value"].to_i * 2
      end
      bk.save
    end
    start += 100
  end until start >= data["total"]

  redirect "/books"
end
