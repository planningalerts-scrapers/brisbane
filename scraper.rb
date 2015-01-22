require 'scraperwiki'
require 'mechanize'

# Scraping from Masterview 2.0

def scrape_page(page)
  page.at("table#ctl00_cphContent_ctl01_ctl00_RadGrid1_ctl00 tbody").search("tr").each do |tr|
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
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end

def scrape_and_follow_next_link(page)
  scrape_page(page)
  nextButton = page.at('.rgPageNext')
  puts "No further pages" if nextButton.nil?
  unless nextButton.nil? || nextButton['onclick'] =~ /return false/
    form = page.forms.first

    # The joy of dealing with ASP.NET
    form['__EVENTTARGET'] = nextButton['name']
    form['__EVENTARGUMENT'] = ''
    # It doesn't seem to work without these stupid values being set.
    # Would be good to figure out where precisely in the javascript these values are coming from.
    form['ctl00%24RadScriptManager1']=
    'ctl00%24cphContent%24ctl00%24ctl00%24cphContent%24ctl00%24Radajaxpanel2Panel%7Cctl00%24cphContent%24ctl00%24ctl00%24RadGrid1%24ctl00%24ctl03%24ctl01%24ctl10'
    form['ctl00_RadScriptManager1_HiddenField']=
    '%3B%3BSystem.Web.Extensions%2C%20Version%3D3.5.0.0%2C%20Culture%3Dneutral%2C%20PublicKeyToken%3D31bf3856ad364e35%3Aen-US%3A0d787d5c-3903-4814-ad72-296cea810318%3Aea597d4b%3Ab25378d2%3BTelerik.Web.UI%2C%20Version%3D2009.1.527.35%2C%20Culture%3Dneutral%2C%20PublicKeyToken%3D121fae78165ba3d4%3Aen-US%3A1e3fef00-f492-4ed8-96ce-6371bc241e1c%3A16e4e7cd%3Af7645509%3A24ee1bba%3Ae330518b%3A1e771326%3Ac8618e41%3A4cacbc31%3A8e6f0d33%3Aed16cbdc%3A58366029%3Aaa288e2d'
    page = form.submit(form.button_with(:name => nextButton['name']))
    scrape_and_follow_next_link(page)
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

scrape_and_follow_next_link(page)
