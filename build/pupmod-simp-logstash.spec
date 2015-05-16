Summary: Logstash SIMP Puppet Module
Name: pupmod-simp-logstash
Version: 1.0.0
Release: 5
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires: pupmod-electrical-logstash >= 0.1.0-0
Requires: pupmod-iptables >= 4.0.0-0
Requires: pupmod-rsyslog >= 4.1.0-1
Requires: pupmod-stunnel >= 4.2.0-0
Requires: pupmod-tcpwrappers >= 2.0.0-6
Requires: puppet >= 2.7.22-1
Buildarch: noarch
Obsoletes: pupmod-simp-logstash-test

Prefix: /etc/puppet/environments/simp/modules

%description
This puppet module uses the LogStash module provided by Richard Pijnenburg
(electrical: https://github.com/electrical) and moulds it into the SIMP
framework with some reasonable defaults.

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}/logstash

dirs='files lib manifests templates'
for dir in $dirs; do
  test -d $dir && cp -r $dir %{buildroot}/%{prefix}/logstash
done

mkdir -p %{buildroot}/%{prefix}/logstash

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(0640,root,puppet,0750)
%{prefix}/logstash/manifests/simp.pp
%{prefix}/logstash/manifests/simp
%{prefix}/logstash/files

%post
#!/bin/sh

%postun
# Post uninstall stuff

%changelog
* Thu Feb 26 2015 Ralph Wright <rwright@onyxpoint.com> - 1.0.0-5
- Added simp logstash filters and associated patterns

* Fri Feb 13 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-4
- Updated to support the new 'simp' environment

* Thu Dec 18 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-3
- Updated the rsyslog::simp material to correct the NAT rule for
  forwarding unencrypted traffic.
- Added iptables rules for allowing plain tcp and udp syslog
  connections.

* Wed Oct 22 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-2
- Update to account for the stunnel module updates in 4.2.0-0

* Sat Sep 06 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-1
- Added support for elasticsearch-curator for log age-off and log
  optimization.
- Added sane defaults for log age-off (one year by default).

* Tue Apr 01 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-0
- Updated to use stunnel::add instead of stunnel::stunnel_add

* Fri Mar 21 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 0.1.0-3
- Added a stunnel rule to handle traditional syslog-tls traffic on port 6514.
- Redirect all Logstash Stunnel traffic to 51400 instead of 514. This prevents
  the use of a local rsyslog loop to get remote logs directed into Logstash.

* Wed Feb 12 2014 Kendall Moore <kmoore@keywcorp.com> - 0.1.0-2
- Updated template to use native booleans instead of strings.

* Mon Oct 07 2013 Nick Markowski <nmarkowski@keywcorp.com> - 0.1.0-1
- Updated template to reference instance variables with @

* Mon Aug 12 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 0.1.0-0
- First cut at SIMP integration of the LogStash module from 'electrical'
  https://github.com/electrical/puppet-logstash.
