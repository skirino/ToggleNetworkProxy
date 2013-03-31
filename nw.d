module main;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.functional;
import std.c.stdlib;
import core.sys.posix.unistd;


immutable string PROXY_IP   = "10.5.134.56";
immutable string PROXY_PORT = "8080";
immutable string PROXY_HOST = PROXY_IP ~ ':' ~ PROXY_PORT;


class ConfFile
{
  string[] lines_ = [];

  this()
  {
    auto f = File(filepath());
    string s;
    while((s = f.readln) !is null){
      lines_ ~= s;
    }
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
    File(filepath(), "w").write(lines_.join(""));
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
      "http_proxy=\"http://"   ~ PROXY_HOST ~ "/\"\n",
      "https_proxy=\"https://" ~ PROXY_HOST ~ "/\"\n",
      "socks_proxy=\"socks://" ~ PROXY_HOST ~ "/\"\n",
    ];
  }
}

class AptConfFile : ConfFile
{
  override string filepath() {return "/etc/apt/apt.conf";}

  override string[] proxySettingLines()
  {
    return [
      "Acquire::http::proxy \"http://"   ~ PROXY_HOST ~ "/\";\n",
      "Acquire::https::proxy \"https://" ~ PROXY_HOST ~ "/\";\n",
      "Acquire::socks::proxy \"socks://" ~ PROXY_HOST ~ "/\";\n",
    ];
  }
}

bool containsProxy(string s)
{
  return std.string.indexOf(s, "proxy") != -1;
}


// Assuming Gnome desktop
void gsettingsProxyOn()
{
  int euid = geteuid();
  seteuid(getuid());

  system("gsettings set org.gnome.system.proxy mode 'manual'");
  system(("gsettings set org.gnome.system.proxy.socks host '" ~ PROXY_IP   ~ "'").toStringz);
  system(("gsettings set org.gnome.system.proxy.socks port '" ~ PROXY_PORT ~ "'").toStringz);

  seteuid(euid);
}

void gsettingsProxyOff()
{
  int euid = geteuid();
  seteuid(getuid());

  system("gsettings set org.gnome.system.proxy mode 'none'");
  system("gsettings reset org.gnome.system.proxy.socks host");

  seteuid(euid);
}


void reconnect()
{
  system("nmcli con down id 'Wired connection 1'");
  system("nmcli con up   id 'Wired connection 1'");
  system("/etc/init.d/dns-clean restart");
}

void useproxy()
{
  auto env = new EnvironmentFile;
  if(env.proxySettingPresent()){
    return;
  }
  env.addProxySetting();
  (new AptConfFile).addProxySetting();

  gsettingsProxyOn();
  reconnect();
}

void unuseproxy()
{
  auto env = new EnvironmentFile;
  if(!env.proxySettingPresent()){
    return;
  }
  env.removeProxySetting();
  (new AptConfFile).removeProxySetting();

  gsettingsProxyOff();
  reconnect();
}

void usage()
{
  writeln(q{
    Usage:
      nw reconnect  -- Reconnect wired connection
      nw useproxy   -- Enable proxy settings and reconnect
      nw unuseproxy -- Disable proxy settings and reconnect
  }.outdent);
}

void main(string[] args)
{
  if(args.length != 2){
    usage();
    return;
  }

  switch(args[1]){
  case ")reconnect":
    reconnect();
    break;
  case "useproxy":
    useproxy();
    break;
  case "unuseproxy":
    unuseproxy();
    break;
  default:
    usage();
  }
}
