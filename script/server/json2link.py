#!/usr/bin/env python3
import sys
import os
import re
import json
import base64
import argparse
import urllib.request
import urllib.parse

class UnknowProtocolException(Exception):
    pass

def get_host_ip():
    if option.debug:
        print("trying to get host ip address ...")
    req = urllib.request.Request(url="https://ipv4.icanhazip.com")
    with urllib.request.urlopen(req, timeout=5) as response:
        body = response.read().decode()
        _ip=body.strip("\n")
        if _ip != "":
            if option.debug:
                print("using host ipaddress: {}, if not intended, use --addr option to specify".format(_ip))
            return _ip

    return ""

def parse_inbounds(jsonobj):
    sses=[]
    vmesses = []
    if "inbounds" in jsonobj:
        try:
            for ib in jsonobj["inbounds"]:
                if ib["protocol"] == "vmess":
                    vmesses+=inbound2vmesslinks(ib) # +=list
                elif ib["protocol"] == "shadowsocks":
                    sses.append(inbound2sslink(ib)) # append(item)
        except UnknowProtocolException:
            pass

    return sses,vmesses

def inbound2sslink(inbound):
    ssobj={}
    ssobj["server"]=""
    ssobj["server_port"]=inbound["port"]
    if "remarks" in inbound:
        ssobj["remarks"]=inbound["remarks"]
    if "group" in inbound:
        ssobj["group"]=inbound["group"]
    ssobj["method"]=inbound["settings"]["method"]
    ssobj["password"]=inbound["settings"]["password"]
    return json2sslink(ssobj)

def inbound2vmesslinks(inbound):
    vmesslinks = []
    _type = "none"
    _host = inbound["host"] if "host" in inbound else ""
    _add = _host if _host!="" else host_ip
    _path = ""
    _listen= inbound["listen"] if "listen" in inbound else ""
    _port = "443" if _listen == "127.0.0.1" else str(inbound["port"])
    _tls = "tls" if _port=="443" else ""
    _ps=""
    _net = ""
    sset = {}

    if "streamSettings" in inbound:
        sset = inbound["streamSettings"]

    if "network" in sset:
        _net = sset["network"]
    else:
        _net = "tcp"

    if option.filter is not None:
        for filt in option.filter:
            if filt.startswith("!"):
                if _net == filt[1:]:
                    raise UnknowProtocolException()
            else:
                if _net != filt:
                    raise UnknowProtocolException()

    if _net == "tcp":
        if "tcpSettings" in sset and \
                "header" in sset["tcpSettings"] and \
                "type" in sset["tcpSettings"]["header"]:
                    _type = sset["tcpSettings"]["header"]["type"]

        if "security" in sset:
            _tls = sset["security"]

    elif _net == "kcp":
        if "kcpSettings" in sset and \
                "header" in sset["kcpSettings"] and \
                "type" in sset["kcpSettings"]["header"]:
                    _type = sset["kcpSettings"]["header"]["type"]

    elif _net == "ws":
        if "wsSettings" in sset and \
                "headers" in sset["wsSettings"] and \
                "Host" in sset["wsSettings"]["headers"]:
                    _host = sset["wsSettings"]["headers"]["Host"]

        if "wsSettings" in sset and "path" in sset["wsSettings"]:
            _path = sset["wsSettings"]["path"]

        if "security" in sset:
            _tls = sset["security"]

    elif _net == "h2" or _net == "http":
        if "httpSettings" in sset and \
                "host" in sset["httpSettings"]:
                    _host = ",".join(sset["httpSettings"]["host"])
        if "httpSettings" in sset and \
                "path" in sset["httpSettings"]:
                    _path = sset["httpSettings"]["path"]
        _tls = "tls"

    elif _net == "quic":
        if "quicSettings" in sset:
            _host = sset["quicSettings"]["security"]
            _path = sset["quicSettings"]["key"]
            _type = sset["quicSettings"]["header"]["type"]

    else:
        raise UnknowProtocolException()

    if "settings" in inbound and "clients" in inbound["settings"]:
        for c in inbound["settings"]["clients"]:
            vobj = dict(
                    id=c["id"], aid=str(c["alterId"]),
                    v="2", tls=_tls, add=_add, port=_port, type=_type, net=_net, path=_path, host=_host, ps=inbound["ps"] if "ps" in inbound else "{}/{}".format(_add, _net))

            # plain replace
            for key, plain in plain_amends.items():
                val = vobj.get(key, None)
                if val is None:
                    continue
                vobj[key] = plain

            # sed-like cmd replace
            for key, opt in sed_amends.items():
                val = vobj.get(key, None)
                if val is None:
                    continue
                vobj[key] = re.sub(opt[0], opt[1], val, opt[2])

            vmesslinks.append(json2vmesslink(vobj))
    return vmesslinks

def parse_amendsed(val):
    if not val.startswith("s"):
        raise ValueError("not sed")
    spliter = val[1:2]
    _, pattern, repl, tags = sedcmd.split(spliter, maxsplit=4)
    return pattern, repl, tags

def json2vmesslink(jsonobj):
    return "vmess://" + base64.urlsafe_b64encode(json.dumps(jsonobj, sort_keys=True).encode('utf-8')).decode().strip("=")

def json2ssrlink(jsonobj):
    jsonobj["server"]=host_ip
    options=["password","obfs_param","protocol_param","remarks","group"]
    for o in options:
        if o in jsonobj:
            jsonobj[o]=base64.urlsafe_b64encode(jsonobj[o].encode('utf-8')).decode().strip("=")
        else:
            jsonobj[o]=""
    ssr_link="{server}:{server_port}:{protocol}:{method}:{obfs}:{password}/?obfsparam={obfs_param}&protoparam={protocol_param}&remarks={remarks}&group={group}".format(**jsonobj)
    ssr_link="ssr://"+base64.urlsafe_b64encode(ssr_link.encode('utf-8')).decode().strip("=")
    return ssr_link

def json2sslink(jsonobj):
    jsonobj["server"]=host_ip
    mp=base64.urlsafe_b64encode("{method}:{password}".format(**jsonobj).encode('utf-8')).decode().strip("=")

    pluginstr=""
    if "plugin" in jsonobj:
        if jsonobj["plugin"]=="obfs-sever":
            pluginstr="obfs-local;{plugin_opts};obfs-host=www.baidu.com".format(**jsonobj)
        elif jsonobj["plugin"]=="v2ray-plugin":
            if jsonobj["plugin_opts"]=="server":
                pluginstr="v2ray-plugin"
            elif jsonobj["plugin_opts"]=="server;tls;host=mydomain.me":
                pluginstr="v2ray-plugin;tls;host=mydomain.me"

    pluginstr=urllib.parse.quote(pluginstr)
    pluginstr="plugin="+pluginstr if pluginstr!="" else ""

    groupstr=""
    if "group" in jsonobj:
        jsonobj["group"]=base64.urlsafe_b64encode(jsonobj["group"].encode('utf-8')).decode().strip("=")
        groupstr="group={group}".format(**jsonobj)

    remarksstr=""
    if "remarks" in jsonobj:
        jsonobj["remarks"]=urllib.parse.quote(jsonobj["remarks"])
        remarksstr="{remarks}".format(**jsonobj)

    tailstr=""
    if pluginstr!="":
        tailstr="/?"+pluginstr
        if groupstr!="":
            tailstr+="&"+groupstr
    else:
        if groupstr!="":
            tailstr="/?"+groupstr
    if remarksstr!="":
        tailstr+="#"+remarksstr

    ss_link="ss://{0}@{server}:{server_port}{1}".format(mp,tailstr,**jsonobj)

    return ss_link

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="json2link convert server side json into links")
    parser.add_argument('-t', '--type',action="store",default="v2ray",help="the type of json file. support ss, ssr, v2ray, all")
    parser.add_argument('-a', '--addr',
            action="store",
            default="",
            help="server address. If not specified, program will detect the current IP")
    parser.add_argument('-f', '--filter',
            action="append",
            help="Protocol Filter, useful for inbounds with different protocols. "
            "FILTER starts with ! means negative selection. Multiple filter is accepted.")
    parser.add_argument('-m', '--amend',
            action="append",
            help="Amend to the output values, can be use multiple times. eg: -m port:80 -m ps:amended")
    parser.add_argument('--debug',
            action="store_true",
            default=False,
            help="debug mode, show more info")
    parser.add_argument('-j', '--json',
            type=argparse.FileType('r'),
            default=sys.stdin,
            help="parse the server side json")

    option = parser.parse_args()

    host_ip = option.addr
    if host_ip == "":
        host_ip = get_host_ip()

    sed_amends = {}
    plain_amends = {}
    if option.amend:
        for s in option.amend:
            key, sedcmd = s.split(":", maxsplit=1)
            try:
                pattern, repl, tags = parse_amendsed(sedcmd)
            except ValueError:
                plain_amends[key] = sedcmd
                continue

            reflag = 0
            if "i" in tags:
                reflag |= re.IGNORECASE
            sed_amends[key] = [pattern, repl, reflag]


    if option.type=="ss":
        jsonobj = json.load(option.json)
        print(json2sslink(jsonobj))
    elif option.type=="ssr":
        jsonobj = json.load(option.json)
        print(json2ssrlink(jsonobj))
    elif option.type=="v2ray":
        jsonobj = json.load(option.json)
        sses,vmesses=parse_inbounds(jsonobj)
        print("\n".join(sses)+"\n")
        print("\n".join(vmesses))
    elif option.type=="all":
        linkfile="/root/gfw/link"

        if os.path.exists(linkfile):
            with open(linkfile, "w") as f:
                pass

        configfile="/etc/v2ray/config.json"
        if os.path.exists(configfile):
            jsonobj=json.load(open(configfile))
            sses,vmesses=parse_inbounds(jsonobj)
            with open(linkfile,"a") as f:
                for vmess in vmesses:
                    f.write(vmess+"\n")
            with open(linkfile,"a") as f:
                for ss in sses:
                    f.write(ss+"\n")

        configfile="/etc/shadowsocks-libev/config.json"
        if os.path.exists(configfile):
            with open(linkfile,"a") as f:
                jsonobj=json.load(open(configfile))
                f.write(json2sslink(jsonobj)+"\n")

        configfile="/etc/shadowsocks-r/config.json"
        if os.path.exists(configfile):
            with open(linkfile,"a") as f:
                jsonobj=json.load(open(configfile))
                f.write(json2ssrlink(jsonobj)+"\n")


