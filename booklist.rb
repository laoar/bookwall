# usage : 
#	 ruby booklist -u username -y year [-m]
# or
#	ruby booklist [-m] -y year -u username
# That means, don't worry about the order of these argus.
#http://www.douban.com/people/username/

require 'nokogiri'  
require 'open-uri'
require 'gruff'

def parse_arg
	user_arg = false
	year_arg = false
	year = 0 
	name = ""
	gen_in_markdown = false

	$*.each do |x| 
		if x == '-u'
			user_arg = true
			year_arg = false
		elsif x == '-y'
			user_arg = false
			year_arg = true
		elsif x == '-m'
			# it is exhausted to tranlate the text to markdown,
			# but my blog is managed via octopress.
			# that's why I do it here.
			# but in order to keep its dependence
			# I don't generate it in octopress format.
			gen_in_markdown = true
		elsif x[0] != '-' && (user_arg == true || year_arg == true)
			if user_arg == true
				name = x
				user_arg = false
			elsif year_arg == true
				year = x.to_i
				year_arg = false
			end	
		else 
			puts "Usage:"
			puts "-u XXX userid on douban, i.e. -u laoar"
			puts "-y NMMN  the year you want to list,i.e. -y 2002"	
			puts "[-m] if this argu is passed, it will generate in Mardown."
			exit false
		end
	end

	return name, year, gen_in_markdown
end

def navigate_to_next(doc, index)
	puts '...'
	got_page = false
	prev_index = 0
	new_uri = ''
	#should navigate to next page
	doc.xpath('//span/link').each do |x|
		if x['rel'] == 'next'
			new_uri = x['href']
			got_page = true
			prev_index = index
		end
	end

	sleep 3

	return got_page, prev_index, new_uri
end

# remove the blanks in the head and the tail of the string.
def remove_extra_blank(string)
	i = 0
	new_str = ""
	size = string.size

	i = 0
	while string[i] != nil && (string[i].ord == 10 || string[i].ord == 32)
		i += 1
	end
	while string[i] != nil && (string[size - 1].ord == 10 || string[size - 1].ord == 32) 
		size -= 1
	end

	new_str = string[i...size]
	
	return new_str 
end

# use a hash to desc the books
$desc = {} 
def parse_html(name, year)
	uri = "http://book.douban.com/people/" + name + "/collect?start=0&sort=time&rating=all&filter=all&mode=grid"

	index = 0
	prev = 0
	this_year = 0
	no_next = false
	month = 0
	human_lang = {
		'chinese' => 0,
		'english' => 0,
		'total' => 0
	}

	each_month = Array.new(12) {|x| x = 0} 

	begin 
		flag = false
		doc = Nokogiri::HTML(open(uri))
		
		#date
		index = prev
		no_record = 0
		record = prev 
		doc.xpath('//span[@class="date"]').each do |x|
			this_year = x.content[0...4].to_i
			if year > this_year
				no_next = true	
			elsif year == this_year	
				$desc[index] = Hash.new
				$desc[index]['date'] =  x.content
				month = $desc[index]['date'][5..6].to_i
				each_month[month - 1] += 1
				index += 1
				record += 1
			else 
				no_record += 1
			end
		end

		if index == prev 
			flag, prev, uri = navigate_to_next(doc, index)
			next
		end

		index = prev
		ignore = no_record
		#title
		doc.xpath('//h2/a').each do |x|  
			if ignore != 0
				ignore -= 1
			else
				if index < record
					$desc[index]['title'] = x['title']
					if ($desc[index]['title'] =~ /\p{Han}/) != nil
						human_lang['chinese'] += 1
					else 
						human_lang['english'] += 1
					end
					index += 1
				end
			end
		end

		index = prev
		ignore = no_record
		#comments
		doc.xpath('//p[@class="comment"]').each do |x|  
			if ignore != 0
				ignore -= 1
			else
				if index < record 
					if x.content != nil 
						$desc[index]['comment'] = remove_extra_blank(x.content)
					end
					index += 1
				end
			end
		end

		index = prev 
		ignore = no_record
		#rating 
		doc.xpath('//div/span').each do |x|
			if x['class'].include?'rating'
				if ignore != 0
					ignore -= 1
				else
					if index < record
						$desc[index]['rating'] = x['class']
						index += 1
					end
				end
			end
		end

		index = prev
		ignore = no_record
		#image
		doc.xpath('//li/div/a/img').each do |x|
			if ignore != 0
				ignore -= 1
			else
				if index < record
					$desc[index]['img'] = x['src']
					index += 1
				end
			end
		end

		if no_next == true 
			break
		end
		flag, prev, uri = navigate_to_next(doc, index)

	end while flag

	human_lang['total'] = $desc.size
	
	return human_lang, each_month
end

def generate_article(name, year, gen_in_markdown) 
	if $desc.empty?
		puts 'Hey buddy, no record found!'
		exit true
	end

	file = File.new("article", "w")
	#how many books in this desc
	num = $desc.size
	npm = (num / 12.0).round(2)
	file.write("<p>This article was automatically generated via <a href=\"https://github.com/laoar/booklist\">Booklist</a>, which is wrote in Ruby by @laoar. It's open to everyone. Feel free to use it.</p>")
	
	file.write("Below are the books " + "@" + name + " have read in " + year.to_s + ". ")
	file.write("There're totally " + num.to_s + " books, that's approximately ")
	file.write(npm.to_s + " books per month, ")
	if npm < 1.0
		file.write("so what the fuck have you been doing?")
	elsif npm > 3.0
		file.write("buddy, could you pls. pay more attention on your work or enjoy the time with your family?")
	else
		file.write("not a bad number. Pls. keep proceeding.")
	end

	if gen_in_markdown
		file.write("<br><br>")
	end
	file.write("\n\n\n")

	i = 0
	# Be aware here, it's written in Markdown.
	# But in order to keep its independence, I did't write others in Markdown. 
	for i in 0...$desc.size
		if gen_in_markdown
			file.write("<h3>")
		end
   		# name. i.e. 1. Leanring abc	
		file.write((i + 1).to_s + '.  ' + ' ' + $desc[i]['title'])
		if gen_in_markdown
			file.write("</h3>")
		end
		file.write("\n")
		if gen_in_markdown
			file.write("<center>")
			# img. 
			file.write('{% img ' + $desc[i]['img'] + ' %}')
			file.write("</center>")
			file.write("\n")
		end
		# rating
		if gen_in_markdown
			file.write("<p>")
		end

		j = 0
		star = $desc[i]['rating'][6].to_i
		file.write('<strong>rating: </strong>')
		for j in 0...star
			file.write('★')
		end
		for j in 0...(5 - star) 
			file.write('☆')
		end
		if gen_in_markdown
			file.write("</p>")
		end
		file.write("\n")

		# comment
		if gen_in_markdown
			file.write("<p>")
		end
		file.write("<strong>comment:</strong>")
		if gen_in_markdown
			file.write("<br>")
		end
		file.write("\n")
		#puts $desc[i]['comment'].size
		file.write($desc[i]['comment'])
		if gen_in_markdown
			file.write("</p>")
		end
		if gen_in_markdown
			file.write("<p>")
		end

		case $desc[i]['comment'].size
		when 0...60
			file.write("<font color=red>[Hey slacker, can't U read it seriously and give more comment?]</font>")
		when 60...150
			file.write("<font color=green>[Good job!]</font>")
		else
			file.write("[hmm...]")
		end
		if gen_in_markdown
			file.write("</p>")
			file.write("<br>")
		end
		file.write("\n\n")
	end	
	
	if gen_in_markdown
		file.write("<h2>Statistics</h2>")
		file.write("<br>")
		file.write("{% img /images/human_lang.png %}")
		file.write("{% img /images/details_month.png %}")
	end

	file.close
end

def generate_graph_lang(lang)
	g = Gruff::Pie.new('400x300')
	g.title = "Chinese and English books"
	g.data 'Chinese Books', (lang['chinese'] * 100.0 / lang['total']).round(0) 
	g.data 'English Books', (lang['english'] * 100.0 / lang['total']).round(0)
	g.write("human_lang.png")
end

def generate_graph_month(month)
 	g = Gruff::Bar.new('400x300')
	g.title = "details in each month"
	g.x_axis_label = "from Jan to Dec"
	g.y_axis_label = "book(s)"
	g.data(" ", month)
	#g.labels = {1=>"1", 2=>"2"}	
	g.write("details_month.png")
end

#Now, let's begin!
user, year, markdown = parse_arg
lang, in_month = parse_html(user, year)
generate_graph_lang(lang)
generate_graph_month(in_month)
generate_article(user, year, markdown)

