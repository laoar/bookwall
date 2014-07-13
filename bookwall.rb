#!/usr/bin/ruby

# usage : ./bookwall username

require 'rubygems'
require 'mechanize'
require 'nokogiri'  
require 'open-uri'

$name = ARGV[0] 
$uri = sprintf("http://book.douban.com/people/%s/collect?start=0&sort=time&rating=all&filter=all&mode=grid", $name);

agent = Mechanize.new
page = agent.get($uri)

$book = File.new("bookwall.html", "a+")
$page = page
begin 
	page = agent.click($page)
	pp page
	page.links_with(:class => 'nbg').each do |link|
#		if !link.href.include?"buylink"
		$book.puts link.node
#		end
	end
	sleep 3
	$page = page.links.find {|l| l.text == '后页>'}
end while $page  
$book.close

=begin

# get the titles of all books 
begin 
	$flag = false
	doc = Nokogiri::HTML(open($uri))
	doc.css('a').each do |link|  
		if link['title']
			if link['href'].include?"subject"
    			puts link['title']
			end
		end	

		if link.text == '后页>'
			$uri = link['href']
			$flag = true
		end
	end
	sleep 3
end while $flag
=end
