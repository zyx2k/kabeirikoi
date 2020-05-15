#!/usr/bin/env ruby

# 	The following code was written by Campbell Murray ( @zyx2k )
#   It is a site spider written in Ruby.  
# 	It will spider a site for URLs then examine each page for 
# 	forms and form fields, saving the information in a text file
# 	with SQLMap compatible querystrings.  This code is intended to 
# 	become part of a much more intricate tool but is still functional 
# 	in its current form.
# 	
# 	The author provides this code without warranty expressed or implied and
# 	accepts no liability for its use by others.  This tool in intended for 
# 	educational purposes only. It is available for public use, modification 
# 	and redistribution under the GPL license agreement.  
	
require 'sqlite3'
require 'uri'
require 'anemone'
require 'mechanize'

def startup()
puts 'Enter a name for this session : '
db_session_name = gets.chomp
puts 'Enter host to spider e.g. http://www.domain.com : '
host_to_spider=gets.chomp

#Validate submitted url
unless (host_to_spider =~ URI::regexp).nil?   
    db = SQLite3::Database.new "#{db_session_name}"
    db.execute "create table tblKabeirikoiURL(ID integer primary key, fldSubPage TEXT)"
    db.execute "create table tblKabeirikoiFORMDATA (ID integer primary key, fldSubPage TEXT, fldFormID TEXT, fldFormData TEXT)"
else
  puts "You entered an invalid URL."
  puts "URLs should be of the format http(s)://domain.com"
end
#crawl the target site and add to db
    Anemone.crawl(host_to_spider) do |anemone|
      anemone.on_every_page do |page|
	sub_page = page.url.to_s	
	begin
	  db.execute('insert into tblKabeirikoiURL (fldSubPage) VALUES (?)', sub_page)
	  puts "+: [" + sub_page + "]"
	rescue SQLite3::Exception => e 
	  puts "Exception occured"
	  puts e
	  puts "-: [" + sub_page + "]"
	rescue Interrupt => e
	   process_stage(db_session_name)
	end
      end
    end

    id = db.last_insert_row_id
    puts "#{id} pages added to the test list\n\n"
 process_stage(db_session_name)
end

def process_stage(db_session_name)
    puts "Processing pages to locate injection points\n\n"
    #retreive sub_page from db and use mechanize to grab form names, fields etc
    agent = Mechanize.new
    agent.user_agent = "Kabeirikoi"
    #open the db
    db = SQLite3::Database.open db_session_name
    db.execute("SELECT fldSubPage FROM tblKabeirikoiURL") do |row| 
      page = row[0]
    puts "URL:: " + page

    begin
    agent.get(page)
           formid = agent.page.forms[0]
           fieldid = agent.page.forms[0].fields
	  
	   #write to screen
	   puts formid
	   
	   #insert form and field information into db
	    fieldid.each { |field_name| 302
	    db.execute('insert into tblKabeirikoiFORMDATA (fldSubPage, fldFormID, fldFormData) VALUES (?, ?, ?)', page.to_s, formid.name, field_name.name	)
	    #write to screen
	    puts field_name.name
	    }
   rescue 
puts "Wrong file type\n\n"
    end
puts "\n\n"
    end
output_stage(db_session_name)
end

def output_stage(db_session_name)
#open the db
db = SQLite3::Database.open db_session_name  

#Output to file
  file_name = db_session_name + ".txt"
  puts "Outputing site structure to #{file_name}\n"
  #cycle through database and write to file
  File.open( file_name, "w" ) do |line|
    
    db.execute("SELECT * FROM tblKabeirikoiURL") do |url|
      urlstr=url[1].to_s
      if urlstr.include? "?" then
    line.puts urlstr
      end
    end
    db.execute("SELECT DISTINCT fldSubPage, fldFormData FROM tblKabeirikoiFORMDATA") do |row| 
      if row[2] !=""
    line.puts row[0].to_s + " --forms"
      end
    end
  end
  #clean up
db.close if db
#bin the db
`rm #{db_session_name}`
end

startup()