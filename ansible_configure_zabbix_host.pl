use Modern::Perl;

use lib "./lib/"; #Prefer code from the local directory

use Zabbix::API;
use Zabbix::API::Host;
use Zabbix::API::HostGroup;
use Zabbix::API::Template;

use Getopt::Long;

my ($user, $password, $jsonrpc_url);
my ($host);
my ($templateNames, $hostGroupNames);
my ($agent_ip, $agent_dns, $agent_port);
my ($tls_psk_identity, $tls_psk);
my ($help);
my $verbose = 1;

Getopt::Long::GetOptions(
    "user=s"                 => \$user,
    "password=s"             => \$password,
    "jsonrpc_url=s"          => \$jsonrpc_url,
    "host=s"                 => \$host,
    "templates=s"            => \$templateNames,
    "groups=s"               => \$hostGroupNames,
    "agent_ip=s"             => \$agent_ip,
    "agent_dns=s"            => \$agent_dns,
    "agent_port=s"           => \$agent_port,
    "tls_psk=s"              => \$tls_psk,
    "tls_psk_identity=s"     => \$tls_psk_identity,

    "help"                   => \$help,
    "verbose:i"              => \$verbose,

) or die("Error in command line arguments\n$!$@");

if ($help) {
    print <<HELP;

This scripts provisions a Koha-Suomi Zabbix-Agent.

All parameters match the ones available to the Zabbix-API endpoints

https://www.zabbix.com/documentation/3.4/manual/api/reference/user/login
https://www.zabbix.com/documentation/3.4/manual/api/reference/host/create


Using the available Ansible-modules was not possible due to them missing some
features needed to secure the agent-server connection at this point in time.
Maybe that will change.

HELP
    exit;
}

#Uncomment if you need to do some testing
#somethingToPlayWith();

my @hostGroupNames = split(/\s+,\s+/, $hostGroupNames);
my @templateNames  = split(/\s+,\s+/, $templateNames);

my $zabbix = Zabbix::API->new(server => $jsonrpc_url,
                              verbosity => 1);

eval { $zabbix->login(user     => $user,
                      password => $password) };
if ($@) { die 'could not authenticate' };


##Make sure that the given host groups exists and fetch their groupids
foreach my $hostGroupName (@hostGroupNames) {
    my $hostGroup = Zabbix::API::HostGroup->new(root => $zabbix, data => { name => $hostGroupName });
    $hostGroup->push();
}
my $hostGroups = $zabbix->fetch('HostGroup', params => { filter => { name => \@hostGroupNames} } );
my @groupidStanza = map {{groupid => $_->id}} @$hostGroups;

##Fetch the given template ids. Provisioning templates automatically is too complex and it is
##better to TODO them via Zabbix's import/export features.
my $templates = $zabbix->fetch('Template', params => { filter => { host => \@templateNames } } );
my @templateidStanza = map {{templateid => $_->id}} @$templates;

##Provision the host
my $host1 = Zabbix::API::Host->new(root => $zabbix, data => {
    host =>       $host,
    groups =>     \@groupidStanza,
    templates =>  \@templateidStanza,
    interfaces => [{
        type =>   1,
        main =>   1,
        useip =>  1,
        ip =>     $agent_ip,
        dns =>    $agent_dns,
        port =>   $agent_port,
    }],
    tls_connect =>      2,
    tls_accept  =>      2,
    tls_psk_identity => $tls_psk_identity,
    tls_psk =>          $tls_psk,
});
$host1->push();


##Close session
$zabbix->raw_query(method => 'user.logout', params => []);




##Invoke this to have meaningful test data
sub somethingToPlayWith {
    $user             = 'zabarbarian';
    $password         = 'burbarburbarbarbarberbir';
    $jsonrpc_url      = 'https://localhost/zabbix/api_jsonrpc.php';
    $host             = 'zabbix_agent';
    $hostGroupNames   = 'Ansibled';
    $templateNames    = 'Template OS Linux';
    $agent_ip         = '127.0.0.1';
    $agent_dns        = '',
    $agent_port       = '10050';
    $tls_psk_identity = 'PSK zabbix_agent';
    $tls_psk          = '6173646173647361646173646173646173647361646173646173646173647361';
}

