# encoding: utf-8
require 'sinatra'
require 'sinatra/namespace'

require 'haml'
require 'nokogiri'
require 'net/http'
require 'digest'

XSD_URL = "https://raw.githubusercontent.com/voc/schedule/master/validator/"\
          "xsd/schedule.xml.xsd"

set :sub_path, ""

set :raw_xsd do
  uri  = URI.parse(XSD_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)

  response.body
end

set :xsd do
  Nokogiri::XML::Schema(settings.raw_xsd)
end

set :xsd_md5 do
  md5 = Digest::MD5.hexdigest(settings.raw_xsd)
  datetime = DateTime.now.strftime("%d.%m.%Y %H:%M")

  { md5: md5, datetime: datetime}
end

error 400..510 do
  'Boom'
end

namespace "#{settings.sub_path}" do
  get '/' do
    haml :index
  end

  post '/validate' do
    if params[:schedulexml] =~ /\Ahttp/
      params[:schedulexml] = get_schedule(params[:schedulexml])
    end

    @errors = validate_xml(params[:schedulexml], settings.xsd)

    case request.content_type
    when /application\/json/
      { "errors" => @errors, "error_count" => @errors.count,
        "xsd_datetime" => settings.xsd_md5[:datetime],
        "xsd_md5" => settings.xsd_md5[:md5],
        "xsd_url" => XSD_URL,
        "request_url" => request.url,
        "acronym" => get_acronym(params[:schedulexml]) }.to_json
    else
      haml :index
    end
  end
end

helpers do
  def get_schedule(url)
    uri  = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
    end
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    response.body
  end

  def validate_xml(xml, xsd)
    doc = Nokogiri::XML(xml)

    errors = []
    xsd.validate(doc).each do |error|
      errors << error.message
    end

    errors
  end

  def get_acronym(xml)
    doc = Nokogiri::XML(xml)
    acronym_element = doc.xpath('.//acronym')

    acronym_element.text
  end

  def xsd_md5(raw_xsd)
    Digest::Md5.hexdigest(raw_xsd)
  end
end
