backend img {
    .host = "127.0.0.1";
    .port = "8090";
}

acl purge {
    "localhost";
    "127.0.0.1";
}

sub vcl_recv {

    remove req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = client.ip;

    if (req.request == "PURGE") {
        if (!client.ip ~ purge) {
            error 405 "not allowed.";
        }
        return(lookup);
    }

    if (req.http.host ~ "^img.ptfish.com") {
        set req.backend = img;
    }
    else {
        error 404 "Unknown HostName!";
    }

    if (req.request != "GET" && req.request != "HEAD") {
        return (pass);
    }

    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
     }

    if (req.url ~ "\.(aspx|asp|php|cgi|jsp)($|\?)") {
        return(pass);
    }
    else {
        return(lookup);
    }
}

sub vcl_fetch {
    if (req.request == "GET" && req.url ~ ".(css|mp3|jpg|png|gif|swf|flv|jpeg|ic                                                                                              o)$") {
        set beresp.ttl = 10d;
    }
    return (deliver);
}

sub vcl_deliver {
    set resp.http.x-hits = obj.hits ;
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    }
    else {
        set resp.http.X-Cache = "MISS";
    }
    remove resp.http.X-Varnish;
    remove resp.http.Via;
    remove resp.http.Server;
    remove resp.http.X-Powered-By;
}

sub vcl_error {
    set obj.http.Content-Type = "text/html; charset=utf-8";
    set obj.http.Retry-After = "5";
    synthetic {"
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        <html>
            <head>
                <title>"} + obj.status + " " + obj.response + {"</title>
            </head>
            <body>
                <h1>Error "} + obj.status + " " + obj.response + {"</h1>
                <p>"} + obj.response + {"</p>
                <h3>Guru Meditation:</h3>
                <p>XID: "} + req.xid + {"</p>
                <hr>
                <p>Fish Cache Server</p>
            </body>
        </html>
"};
     return (deliver);
}