# Dynamically update config of haproxy
class profile::haproxy::consul_template (
  String $service_name,
  Optional[Boolean] $ssl_check = false,
  Optional[String] $version = '0.27.0',
  Optional[String] $http_proxy = "${lookup('profile::haproxy::full_http_proxy')}",
  Optional[String] $https_proxy = "${lookup('profile::haproxy::full_https_proxy')}",
) {
  file { '/etc/haproxy.ctmpl':
    ensure  => present,
    mode    => '0755',
    content => template('profile/haproxy/haproxy.ctmpl.erb'),
  }

  class { 'consul_template':
    http_proxy    => $http_proxy,
    https_proxy   => $https_proxy,
    version       => $version,
    pretty_config => true,
  }

  consul_template::watch { 'haproxy':
    config_hash => {
      perms       => '0644',
      source      => '/etc/haproxy/haproxy.ctmpl',
      destination => '/etc/haproxy/haproxy.cfg',
      backup      => true,
      command     => 'systemctl reload haproxy',
    },
    require     => File['/etc/haproxy/haproxy.ctmpl'],
  }
}
