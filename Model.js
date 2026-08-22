.pragma library

function parseScan(rawOutput) {
  if (!rawOutput || rawOutput.trim() === "") {
    return defaultState();
  }
  try {
    var data = JSON.parse(rawOutput);
    var gitData = data.git || {};
    var projData = data.project || {};
    return {
      project: {
        path: projData.path || "",
        name: projData.name || "No Project",
        stack: projData.stack || "generic",
        hasCompose: projData.hasCompose === true,
        isManual: projData.isManual === true
      },
      discoveredProjects: Array.isArray(data.discoveredProjects) ? data.discoveredProjects : [],
      git: {
        hasRepo: gitData.hasRepo === true,
        repoPath: gitData.repoPath || "",
        repoName: gitData.repoName || "",
        branch: gitData.branch || "",
        branches: Array.isArray(gitData.branches) ? gitData.branches : [],
        lastCommit: gitData.lastCommit || "",
        commits: Array.isArray(gitData.commits) ? gitData.commits : [],
        stashes: Array.isArray(gitData.stashes) ? gitData.stashes : [],
        dirty: typeof gitData.dirty === "number" ? gitData.dirty : 0,
        staged: typeof gitData.staged === "number" ? gitData.staged : 0,
        untracked: typeof gitData.untracked === "number" ? gitData.untracked : 0,
        ahead: typeof gitData.ahead === "number" ? gitData.ahead : 0,
        behind: typeof gitData.behind === "number" ? gitData.behind : 0,
        remoteUrl: gitData.remoteUrl || "",
        isGitHub: gitData.isGitHub === true,
        githubRepo: gitData.githubRepo || "",
        pullRequests: Array.isArray(gitData.pullRequests) ? gitData.pullRequests : [],
        issues: Array.isArray(gitData.issues) ? gitData.issues : []
      },
      ports: Array.isArray(data.ports) ? data.ports : [],
      docker: data.docker || { available: false, containers: [] }
    };
  } catch (e) {
    console.warn("DevEnv: Failed to parse scan output:", e);
    return defaultState();
  }
}

function defaultState() {
  return {
    project: { path: "", name: "No Project", stack: "generic", hasCompose: false, isManual: false },
    discoveredProjects: [],
    git: {
      hasRepo: false,
      repoPath: "",
      repoName: "",
      branch: "",
      branches: [],
      lastCommit: "",
      commits: [],
      stashes: [],
      dirty: 0,
      staged: 0,
      untracked: 0,
      ahead: 0,
      behind: 0,
      remoteUrl: "",
      isGitHub: false,
      githubRepo: "",
      pullRequests: [],
      issues: []
    },
    ports: [],
    docker: { available: false, containers: [] }
  };
}

function groupPorts(portsList) {
  var list = portsList || [];
  var projectMap = {};
  var projectGroups = [];
  var processList = [];

  for (var i = 0; i < list.length; i++) {
    var item = list[i];
    var catType = item.categoryType || "process";
    var catName = item.categoryName || "General Processes";

    if (catType === "project") {
      if (!projectMap[catName]) {
        var groupObj = {
          name: catName,
          path: item.categoryPath || "",
          type: "project",
          ports: []
        };
        projectMap[catName] = groupObj;
        projectGroups.push(groupObj);
      }
      projectMap[catName].ports.push(item);
    } else {
      processList.push(item);
    }
  }

  var result = [];
  for (var p = 0; p < projectGroups.length; p++) {
    result.push(projectGroups[p]);
  }
  if (processList.length > 0) {
    result.push({
      name: "General Processes",
      path: "",
      type: "process",
      ports: processList
    });
  }
  return result;
}

function shortenPath(p) {
  if (!p) return "";
  var str = String(p);
  var match = str.match(/^(\/home\/[^\/]+)/);
  if (match) {
    if (str === match[1]) return "~";
    return "~" + str.substring(match[1].length);
  }
  if (str.indexOf("/root") === 0) {
    if (str === "/root") return "~";
    return "~" + str.substring(5);
  }
  return str;
}

function getProcessIcon(processName) {
  var p = String(processName || "").toLowerCase();
  if (p.indexOf("node") >= 0 || p.indexOf("vite") >= 0 || p.indexOf("next") >= 0 || p.indexOf("bun") >= 0 || p.indexOf("deno") >= 0) return "";
  if (p.indexOf("python") >= 0 || p.indexOf("uvicorn") >= 0 || p.indexOf("gunicorn") >= 0 || p.indexOf("flask") >= 0) return "";
  if (p.indexOf("cargo") >= 0 || p.indexOf("rust") >= 0) return "";
  if (p.indexOf("go") >= 0) return "";
  if (p.indexOf("docker") >= 0) return "";
  if (p.indexOf("postgres") >= 0 || p.indexOf("psql") >= 0) return "";
  if (p.indexOf("redis") >= 0) return "";
  if (p.indexOf("caddy") >= 0 || p.indexOf("nginx") >= 0 || p.indexOf("httpd") >= 0) return "󰒋";
  if (p.indexOf("steam") >= 0) return "󰓓";
  if (p.indexOf("agy") >= 0 || p.indexOf("opencode") >= 0 || p.indexOf("code") >= 0) return "󰅩";
  return "󰒋";
}

function getStackIcon(stack) {
  var s = String(stack || "").toLowerCase();
  if (s === "node") return "";
  if (s === "rust") return "";
  if (s === "python") return "";
  if (s === "go") return "";
  return "󰉋";
}

function getContainerStateIcon(state) {
  var s = String(state || "").toLowerCase();
  if (s === "running") return "󰄳";
  if (s === "restarting" || s === "starting") return "󰑐";
  if (s === "exited" || s === "dead" || s === "stopped") return "󰅖";
  return "󰋜";
}

function formatPortUrl(ip, port) {
  var host = "localhost";
  if (ip && ip !== "0.0.0.0" && ip !== "127.0.0.1" && ip !== "::" && ip !== "::1") {
    host = ip.replace(/%.*/, "");
  }
  return "http://" + host + ":" + port;
}

function copyToClipboard(text) {
  if (text === undefined || text === null) return;
  try {
    if (typeof Quickshell !== "undefined" && typeof Quickshell.execDetached === "function") {
      Quickshell.execDetached(["wl-copy", String(text)]);
    }
  } catch (e) {
    console.warn("DevEnv: copyToClipboard error:", e);
  }
}

// ---------------------------------------------------------------- Toolbox Helpers

function formatJson(input, indent) {
  if (!input || input.trim() === "") return "";
  var spaces = typeof indent === "number" ? indent : 2;
  var parsed = JSON.parse(input);
  return JSON.stringify(parsed, null, spaces);
}

function minifyJson(input) {
  if (!input || input.trim() === "") return "";
  var parsed = JSON.parse(input);
  return JSON.stringify(parsed);
}

function validateJson(input) {
  if (!input || input.trim() === "") return { valid: false, error: "Empty input" };
  try {
    var parsed = JSON.parse(input);
    var isArr = Array.isArray(parsed);
    var count = isArr ? parsed.length : Object.keys(parsed).length;
    return {
      valid: true,
      type: isArr ? "Array (" + count + " items)" : "Object (" + count + " keys)",
      bytes: encodeURIComponent(input).replace(/%[A-F\d]{2}/g, 'U').length
    };
  } catch (e) {
    return { valid: false, error: e.message || "Invalid JSON syntax" };
  }
}

function timestampToDate(timestampStr) {
  var n = Number(timestampStr);
  if (!isFinite(n) || n <= 0) return { valid: false, error: "Invalid Timestamp" };
  var ms = n < 10000000000 ? n * 1000 : n;
  var d = new Date(ms);
  if (isNaN(d.getTime())) return { valid: false, error: "Invalid Timestamp" };

  return {
    valid: true,
    seconds: Math.floor(ms / 1000),
    milliseconds: ms,
    utc: d.toISOString().replace("T", " ").replace("Z", " UTC"),
    iso: d.toISOString(),
    local: d.toLocaleString(),
    relative: formatRelativeTime(d)
  };
}

function dateToTimestamp(dateStr) {
  var d;
  if (!dateStr || dateStr.trim() === "" || dateStr.trim().toLowerCase() === "now") {
    d = new Date();
  } else {
    d = new Date(dateStr);
  }
  if (isNaN(d.getTime())) return { valid: false, error: "Invalid Date String" };

  return {
    valid: true,
    seconds: Math.floor(d.getTime() / 1000),
    milliseconds: d.getTime(),
    utc: d.toISOString().replace("T", " ").replace("Z", " UTC"),
    local: d.toLocaleString(),
    relative: formatRelativeTime(d)
  };
}

function formatRelativeTime(d) {
  var diffMs = Date.now() - d.getTime();
  var diffSec = Math.floor(Math.abs(diffMs) / 1000);
  var isPast = diffMs >= 0;
  var prefix = isPast ? "" : "in ";
  var suffix = isPast ? " ago" : "";

  if (diffSec < 5) return "just now";
  if (diffSec < 60) return prefix + diffSec + " seconds" + suffix;
  var diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return prefix + diffMin + " min" + (diffMin === 1 ? "" : "s") + suffix;
  var diffHours = Math.floor(diffMin / 60);
  if (diffHours < 24) return prefix + diffHours + " hour" + (diffHours === 1 ? "" : "s") + suffix;
  var diffDays = Math.floor(diffHours / 24);
  return prefix + diffDays + " day" + (diffDays === 1 ? "" : "s") + suffix;
}

function base64Encode(str) {
  if (!str) return "";
  try {
    if (typeof TextEncoder !== "undefined") {
      return Qt.btoa(new TextEncoder().encode(str));
    }
    return Qt.btoa(unescape(encodeURIComponent(str)));
  } catch (e) {
    return Qt.btoa(unescape(encodeURIComponent(str)));
  }
}

function base64Decode(str) {
  if (!str) return "";
  try {
    var res = Qt.atob(str.trim());
    if (typeof TextDecoder !== "undefined" && res instanceof ArrayBuffer) {
      return new TextDecoder().decode(res);
    }
    if (typeof res !== "string") {
      var arr = new Uint8Array(res);
      var binary = "";
      for (var i = 0; i < arr.byteLength; i++) {
        binary += String.fromCharCode(arr[i]);
      }
      return decodeURIComponent(escape(binary));
    }
    return decodeURIComponent(escape(res));
  } catch (e) {
    return "Error: Invalid Base64 String";
  }
}

function urlEncode(str) {
  return encodeURIComponent(str || "");
}

function urlDecode(str) {
  try {
    return decodeURIComponent(str || "");
  } catch (e) {
    return "Error: Invalid URL encoding";
  }
}

function generateUuidV4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0;
    var v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function generateUuidV7() {
  var now = Date.now();
  var hexTime = now.toString(16);
  while (hexTime.length < 12) hexTime = "0" + hexTime;
  var p1 = hexTime.substring(0, 8);
  var p2 = hexTime.substring(8, 12);
  var randHex = "";
  for (var i = 0; i < 18; i++) {
    randHex += Math.floor(Math.random() * 16).toString(16);
  }
  var p3 = "7" + randHex.substring(0, 3);
  var varDigit = (8 + Math.floor(Math.random() * 4)).toString(16);
  var p4 = varDigit + randHex.substring(3, 6);
  var p5 = randHex.substring(6, 18);
  return p1 + "-" + p2 + "-" + p3 + "-" + p4 + "-" + p5;
}

function generateUuid(version) {
  return version === "v7" ? generateUuidV7() : generateUuidV4();
}

function generateUuids(options) {
  var opt = options || {};
  var count = typeof opt.count === "number" ? Math.max(1, Math.min(opt.count, 50)) : 1;
  var version = opt.version || "v4";
  var uppercase = opt.uppercase === true;
  var hyphens = opt.hyphens !== false;
  var results = [];

  for (var i = 0; i < count; i++) {
    var uid = version === "v7" ? generateUuidV7() : generateUuidV4();
    if (!hyphens) {
      uid = uid.replace(/-/g, "");
    }
    if (uppercase) {
      uid = uid.toUpperCase();
    }
    results.push(uid);
  }
  return results;
}
