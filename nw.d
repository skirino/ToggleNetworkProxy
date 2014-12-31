module nw;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.functional;
import std.process;

// CONNECTION_NAME, PROXY_IP, PROXY_PORT and PROXY_HOST should be defined in constants.d
import constants;


pure bool containsProxy(string s)
{
  return std.string.indexOf(s, "proxy") != -1 || std.string.indexOf(s, "PROXY") != -1;
}

class ConfFile
{
  string[] lines_ = [];

  this()
  {
    auto f = File(filepath());
    lines_ = f.byLine.map!(cs => cs.idup).array;
  }

  bool proxySettingPresent()
  {
    return lines_.any!(containsProxy);
  }

  void addProxySetting()
  {
    lines_ ~= proxySettingLines();
    updateConfFile();
  }

  void removeProxySetting()
  {
    lines_ = lines_.filter!(not!(containsProxy)).array;
    updateConfFile();
  }

  void updateConfFile()
  {
    File(filepath(), "w").write(lines_.join("\n") ~ "\n");
  }

  abstract string filepath();
  abstract string[] proxySettingLines();
}

class EnvironmentFile : ConfFile
{
  override string filepath() {return "/etc/environment";}

  override string[] proxySettingLines()
  {
    return [
      "http_proxy=\"http://"   ~ PROXY_HOST ~ "/\"",
      "ftp_proxy=\"ftp://"     ~ PROXY_HOST ~ "/\"",
      "https_proxy=\"https://" ~ PROXY_HOST ~ "/\"",
      "no_proxy=\"127.0.0.1,localhost\"",

      // For programs that only look at env vars with capital letters
      "HTTP_PROXY=\"http://"   ~ PROXY_HOST ~ "/\"",
      "FTP_PROXY=\"ftp://"     ~ PROXY_HOST ~ "/\"",
      "HTTPS_PROXY=\"https://" ~ PROXY_HOST ~ "/\"",
      "NO_PROXY=\"127.0.0.1,localhost\"",
    ];
  }
}

// Assuming Gnome desktop
void gsettingsProxyOn()
{
  executeShell( "dbus-launch gsettings set org.gnome.system.proxy mode 'manual'");
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.http  host '" ~ PROXY_IP   ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.http  port '" ~ PROXY_PORT ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.ftp   host '" ~ PROXY_IP   ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.ftp   port '" ~ PROXY_PORT ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.https host '" ~ PROXY_IP   ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.https port '" ~ PROXY_PORT ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.socks host '" ~ PROXY_IP   ~ "'"));
  executeShell(("dbus-launch gsettings set org.gnome.system.proxy.socks port '" ~ PROXY_PORT ~ "'"));
}

void gsettingsProxyOff()
{
  executeShell("dbus-launch gsettings set   org.gnome.system.proxy mode 'none'");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.http  host");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.http  port");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.ftp   host");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.ftp   port");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.https host");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.https port");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.socks host");
  executeShell("dbus-launch gsettings reset org.gnome.system.proxy.socks port");
}


void reconnect()
{
  executeShell("nmcli con down id '" ~ CONNECTION_NAME ~ "'");
  executeShell("nmcli con up   id '" ~ CONNECTION_NAME ~ "'");
  executeShell("[ -f '/etc/init.d/dns-clean' ] && /etc/init.d/dns-clean restart");
}

void proxyon()
{
  auto env = new EnvironmentFile;
  if(env.proxySettingPresent()){
    return;
  }
  env.addProxySetting();

  gsettingsProxyOn();
  reconnect();
}

void proxyoff()
{
  auto env = new EnvironmentFile;
  if(!env.proxySettingPresent()){
    return;
  }
  env.removeProxySetting();

  gsettingsProxyOff();
  reconnect();
}

void usage()
{
  writeln(q{
    Usage:
      nw reconnect -- Reconnect wired connection
      nw proxyon   -- Enable proxy settings and reconnect
      nw proxyoff  -- Disable proxy settings and reconnect
  }.outdent);
}

void main(string[] args)
{
  if(args.length != 2){
    usage();
    return;
  }

  switch(args[1]){
  case "reconnect":
    reconnect();
    break;
  case "proxyon":
    proxyon();
    break;
  case "proxyoff":
    proxyoff();
    break;
  default:
    usage();
  }
}
