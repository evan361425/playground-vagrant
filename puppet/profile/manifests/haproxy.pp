# HAProxy base class
class profile::haproxy (
  String $apt_package_name,
  String $http_proxy,
  String $https_proxy,
) {
  package { 'software-properties-common':
    ensure => present,
    name   => 'software-properties-common',
  }

  exec { 'install-haproxy-ppa':
    provider => 'shell',
    command  => "export https_proxy=${https_proxy} && export http_proxy=${http_proxy} && /usr/bin/add-apt-repository ppa:vbernat/haproxy-2.4 && /usr/bin/apt-get update -qq",
    user     => 'root',
  }

  file { 'haproxy-check-installed-script':
    ensure => present,
    mode   => '0755',
    source => 'puppet:///modules/profile/haproxy/haproxy-check-installed.sh',
    path   => '/tmp/haproxy-check-installed.sh',
  }

  exec { 'install-haproxy':
    provider => 'shell',
    command  => "export https_proxy=${https_proxy} && export http_proxy=${http_proxy} && /usr/bin/apt-get install -y haproxy=${apt_package_name} || exit 0",
    user     => 'root',
    unless   => '/tmp/haproxy-check-installed.sh',
    require  => File['haproxy-check-installed-script'],
  }
}
