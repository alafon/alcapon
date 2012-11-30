def unindent(string)
  indentation = string[/\A\s*/]
  string.strip.gsub(/^#{indentation}/, "")
end

def print_dotted( message, options={} )
  defaults_options = { :eol => false,
                       :sol => false,
                       :max_length => 40,
                       :eol_msg => false }

  options = defaults_options.merge( options )
  message = "#{message} " + "." * [0,options[:max_length]-message.length-1].max

  if options[:sol]
    message = "\n#{message}"
  end

  if options[:eol_msg]
    message += " #{options[:eol_msg]}"
  end

  if options[:eol]
    puts message
  else
    print message
  end
end

def ezp5?
  return ( fetch( :ezpublish_version, nil ) == 5 )
end

def ezp_legacy_path(path='')
  elements = Array.new

  if( fetch( :ezp_legacy, "" ) != "" )
    elements += [ "#{ezp_legacy}" ]
  end

  if( path != '' )
    elements += [ "#{path}" ]
  end

  return File.join( elements )
end

def alcapon_message(string)
  puts( "[alcapon]".green+" #{string}" )
end
