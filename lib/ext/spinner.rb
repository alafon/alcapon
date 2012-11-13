# spinner stuff
# inspired from http://jondavidjohn.com/blog/2012/04/cleaning-up-capistrano-deployment-output
@spinner_running = false
@chars = ['|', '/', '-', '\\']
@spinner = Thread.new do
  loop do
    unless @spinner_running
      Thread.stop
    end
    print @chars[0]
    sleep(0.1)
    print "\b"
    @chars.push @chars.shift
  end
end

def start_spinner
  @spinner_running = true
  @spinner.wakeup
end

# stops the spinner and backspaces over last displayed character
def stop_spinner
  @spinner_running = false
  print "\b"
end