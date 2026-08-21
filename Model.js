.pragma library

function parseScan(rawOutput) {
  if (!rawOutput || rawOutput.trim() === "") {
    return defaultState();
  }
  try {
    var data = JSON.parse(rawOutput);
    return {
      project: data.project || { path: "", name: "No Project", stack: "generic", hasCompose: false },
      git: data.git || { hasRepo: false, branch: "", lastCommit: "", dirty: 0, staged: 0, untracked: 0, ahead: 0, behind: 0 },
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
    project: { path: "", name: "No Project", stack: "generic", hasCompose: false },
    git: { hasRepo: false, branch: "", lastCommit: "", dirty: 0, staged: 0, untracked: 0, ahead: 0, behind: 0 },
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
  var home = "/home/dyeye";
  if (str === home) return "~";
  if (str.indexOf(home + "/") === 0) {
    return "~" + str.substring(home.length);
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

function timestampToDate(timestampStr) {
  var n = Number(timestampStr);
  if (!isFinite(n) || n <= 0) return "Invalid Timestamp";
  if (n < 10000000000) n = n * 1000;
  var d = new Date(n);
  return d.toISOString().replace("T", " ").replace("Z", " UTC") + " (" + d.toLocaleString() + ")";
}

function dateToTimestamp(dateStr) {
  var d = dateStr && dateStr.trim() !== "" ? new Date(dateStr) : new Date();
  if (isNaN(d.getTime())) return "Invalid Date";
  return {
    seconds: Math.floor(d.getTime() / 1000),
    milliseconds: d.getTime()
  };
}

function base64Encode(str) {
  return Qt.btoa(unescape(encodeURIComponent(str || "")));
}

function base64Decode(str) {
  try {
    return decodeURIComponent(escape(Qt.atob(str || "")));
  } catch (e) {
    return "Error: Invalid Base64 String";
  }
}

function generateUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0;
    var v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
