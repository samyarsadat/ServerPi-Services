<?php
// ServerPi Services - Roundcube configuration

$config["use_https"] = true;

// Managesieve
$mail_host = getenv("MAIL_HOST") ?: "mail.ssa-selfhosted.com";
$config["managesieve_host"] = "tls://" . $mail_host;
$config["managesieve_port"] = 4190;

// Security
$config["enable_installer"] = false;
$config["ip_check"]         = true;
$config["referer_check"]    = true;
$config["session_lifetime"] = 30;
$config["log_logins"]       = true;
