require 'scraperwiki'
require 'mechanize'

# Scraping from Masterview 2.0

def scrape_page(page)
  page.at("table#ctl00_cphContent_ctl01_ctl00_RadGrid1_ctl00 tbody").search("tr")[2..-1].each do |tr|
    tds = tr.search('td').map{|t| t.inner_text.gsub("\r\n", "").strip}
    day, month, year = tds[3].split("/").map{|s| s.to_i}
    record = {
      "info_url" => (page.uri + tr.search('td').at('a')["href"]).to_s,
      "council_reference" => tds[1].split(" - ")[0].squeeze(" ").strip,
      "date_received" => Date.new(year, month, day).to_s,
      "description" => tds[1].split(" - ")[1..-1].join(" - ").squeeze(" ").strip,
      "address" => tds[2].squeeze(" ").strip,
      "date_scraped" => Date.today.to_s
    }
    record["comment_url"] = "https://sde.brisbane.qld.gov.au/services/startDASubmission.do?direct=true&daNumber=" + CGI.escape(record["council_reference"]) + "&sdeprop=" + CGI.escape(record["address"])
    #p record
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      ScraperWiki.save_sqlite(['council_reference'], record)
      puts record
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end

url = "https://pdonline.brisbane.qld.gov.au/MasterViewUI/Modules/ApplicationMaster/default.aspx?page=found&1=thismonth&6=F"

agent = Mechanize.new

# Read in a page
page = agent.get(url)

# This is weird. There are two forms with the Agree / Disagree buttons. One of them
# works the other one doesn't. Go figure.
form = page.forms.first
button = form.button_with(value: "I Agree")
raise "Can't find agree button" if button.nil?
page = form.submit(button)
page = agent.get(url)

scrape_page(page)
