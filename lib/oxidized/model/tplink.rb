class TPLink < Oxidized::Model
  using Refinements

  # Tested with TP-Link JetStream switches and the TP-Link DeltaStream
  # DS-P7001-08 GPON OLT (SW 1.0.0). The OLT enables with no password and
  # serves config from privileged mode; see the enable handling in post_login.

  # tp-link prompt
  prompt /^\r?([\w.@()-]+[#>]\s?)$/
  comment '! '

  # handle paging
  # workaround for sometimes missing whitespaces with "\s?"
  expect /Press\s?any\s?key\s?to\s?continue\s?\(Q\s?to\s?quit\)/ do |data, re|
    send ' '
    data.sub re, ''
  end

  # send carriage return because \n with the command is not enough
  # checks if line ends with prompt >,# or \r,\nm otherwise send \r
  expect /[^>#\r\n]$/ do |data, re|
    send "\r"
    data.sub re, ''
  end

  cmd :all do |cfg|
    # remove unwanted paging line
    cfg.gsub! /^Press any key to contin.*/, ''
    # normalize linefeeds
    cfg.gsub! /(\r|\r\n|\n\r)/, "\n"
    # remove empty lines
    cfg.each_line.reject { |line| line.match /^[\r\n\s\u0000#]+$/ }.join
  end

  cmd :secret do |cfg|
    cfg.gsub! /^enable password (\S+)/, 'enable password <secret hidden>'
    cfg.gsub! /^user (\S+) password (\S+) (.*)/, 'user \1 password <secret hidden> \3'
    cfg.gsub! /^(snmp-server community).*/, '\\1 <configuration removed>'
    cfg.gsub! /secret (\d+) (\S+).*/, '<secret hidden>'
    cfg
  end

  cmd 'show system-info' do |cfg|
    cfg.gsub! /(System Time\s+-).*/, '\\1 <stripped>'
    cfg.gsub! /(Running Time\s+-).*/, '\\1 <stripped>'
    comment cfg.each_line.to_a[3..-3].join
  end

  cmd 'show running-config' do |cfg|
    lines = cfg.each_line.to_a[1..-1]
    # cut config after "end"
    lines[0..lines.index("end\n")].join
  end

  cfg :telnet, :ssh do
    username /^User ?[nN]ame:/
    password /^\r?Password:/
    newline "\r\n"
  end

  cfg :telnet, :ssh do
    post_login do
      # Enter privileged (enable) mode if the device offers it. The prompt is
      # ">" in user mode and "#" once enabled, and the commands below
      # (terminal length 0, show system-info, show running-config) need "#" on
      # devices that distinguish the two modes (e.g. the DeltaStream GPON OLT,
      # which enables with no password and jumps straight to "#").
      #
      # Using cmd (not send) resets the read buffer, so we wait for the device's
      # real response instead of matching the stale user-mode prompt, and accept
      # three outcomes: a password challenge, the enabled "#" prompt, or a
      # returned ">". The last case (device without an enable command, or one
      # declining it) is left untouched so setups that never needed enable keep
      # working as before. A password, if asked for, comes from vars(:enable),
      # falling back to the login password.
      out = cmd "enable", Regexp.union(/^\r?[pP]assword:/, @node.prompt)
      cmd((vars(:enable) || @node.auth[:password]).to_s) if out =~ /[pP]assword:/

      cmd 'terminal length 0'
    end

    pre_logout do
      send "exit\r\n"
      send "logout\r\n"
    end
  end
end
