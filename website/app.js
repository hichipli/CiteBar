(function () {
  const owner = document.body.dataset.owner || "hichipli";
  const repo = document.body.dataset.repo || "CiteBar";

  const releaseVersionEl = document.getElementById("release-version");
  const releaseTitleEl = document.getElementById("release-title");
  const releaseDateEl = document.getElementById("release-date");
  const releaseArtifactEl = document.getElementById("release-artifact");
  const releaseSizeEl = document.getElementById("release-size");
  const releaseDownloadCountEl = document.getElementById("release-download-count");
  const releaseHighlightsEl = document.getElementById("release-highlights");
  const releaseNotesLinkEl = document.getElementById("release-notes-link");
  const releaseHistoryLinkEl = document.getElementById("release-history-link");

  const primaryDownloadEl = document.getElementById("download-button");
  const secondaryDownloadEl = document.getElementById("download-button-secondary");

  const githubStarsLinkEl = document.getElementById("github-stars");
  const githubStarsCountEl = document.getElementById("github-stars-count");

  const commandEl = document.getElementById("quarantine-command");
  const copyButtonEl = document.getElementById("copy-command-btn");
  const copyStatusEl = document.getElementById("copy-status");
  const yearEl = document.getElementById("year");

  const releaseApiUrl = "https://api.github.com/repos/" + owner + "/" + repo + "/releases/latest";
  const repoApiUrl = "https://api.github.com/repos/" + owner + "/" + repo;
  const fallbackReleaseUrl = "https://github.com/" + owner + "/" + repo + "/releases/latest";
  const fallbackReleaseHistoryUrl = "https://github.com/" + owner + "/" + repo + "/releases";
  const fallbackRepoUrl = "https://github.com/" + owner + "/" + repo;

  const releaseCacheKey = "citebar.latestRelease.v3";
  const repoCacheKey = "citebar.repoStats.v1";
  const releaseCacheMaxAgeMs = 45 * 60 * 1000;
  const repoCacheMaxAgeMs = 6 * 60 * 60 * 1000;

  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  function setText(element, value) {
    if (element) {
      element.textContent = value;
    }
  }

  function setHref(element, value) {
    if (element) {
      element.href = value;
    }
  }

  function formatDate(isoDate) {
    if (!isoDate) {
      return "Unknown";
    }

    const date = new Date(isoDate);
    if (Number.isNaN(date.getTime())) {
      return "Unknown";
    }

    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric"
    });
  }

  function formatFileSize(bytes) {
    if (!Number.isFinite(bytes) || bytes <= 0) {
      return "size unavailable";
    }

    const mb = bytes / (1024 * 1024);
    return mb.toFixed(1) + " MB";
  }

  function formatNumber(value) {
    if (!Number.isFinite(value)) {
      return "-";
    }

    return new Intl.NumberFormat("en-US").format(value);
  }

  function stripMarkdown(text) {
    return text
      .replace(/`([^`]+)`/g, "$1")
      .replace(/\*\*([^*]+)\*\*/g, "$1")
      .replace(/\*([^*]+)\*/g, "$1")
      .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
      .replace(/^[^A-Za-z0-9]+/, "")
      .trim();
  }

  function extractHighlights(markdownBody) {
    if (typeof markdownBody !== "string" || markdownBody.trim() === "") {
      return [];
    }

    const lines = markdownBody.split(/\r?\n/);
    const highlights = [];
    let inWhatsNewSection = false;
    let sawWhatsNewHeading = false;

    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i].trim();
      const lower = line.toLowerCase();

      if (lower.startsWith("## ")) {
        if (lower.includes("what's new") || lower.includes("whats new")) {
          inWhatsNewSection = true;
          sawWhatsNewHeading = true;
          continue;
        }

        if (inWhatsNewSection) {
          break;
        }
      }

      if (!inWhatsNewSection || !line.startsWith("- ")) {
        continue;
      }

      const cleaned = stripMarkdown(line.slice(2));
      if (cleaned) {
        highlights.push(cleaned);
      }

      if (highlights.length >= 4) {
        return highlights;
      }
    }

    if (sawWhatsNewHeading && highlights.length > 0) {
      return highlights;
    }

    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i].trim();
      if (!line.startsWith("- ")) {
        continue;
      }

      const cleaned = stripMarkdown(line.slice(2));
      if (cleaned) {
        highlights.push(cleaned);
      }

      if (highlights.length >= 4) {
        break;
      }
    }

    return highlights;
  }

  function renderHighlights(items) {
    if (!releaseHighlightsEl) {
      return;
    }

    releaseHighlightsEl.innerHTML = "";

    const source = Array.isArray(items) && items.length > 0
      ? items
      : ["Release highlights unavailable right now."];

    source.forEach(function (item) {
      const li = document.createElement("li");
      li.textContent = item;
      releaseHighlightsEl.appendChild(li);
    });
  }

  function pickPreferredAsset(assets) {
    if (!Array.isArray(assets) || assets.length === 0) {
      return null;
    }

    const dmgAssets = assets.filter(function (asset) {
      return asset && typeof asset.name === "string" && asset.name.toLowerCase().endsWith(".dmg");
    });

    const universal = dmgAssets.find(function (asset) {
      return asset.name.toLowerCase().includes("universal");
    });

    if (universal) {
      return universal;
    }

    if (dmgAssets.length > 0) {
      return dmgAssets[0];
    }

    return assets[0] || null;
  }

  function applyDownloadUrl(url) {
    const safeUrl = url || fallbackReleaseUrl;
    setHref(primaryDownloadEl, safeUrl);
    setHref(secondaryDownloadEl, safeUrl);
  }

  function applyReleaseData(releaseData, sourceLabel) {
    const version = releaseData && typeof releaseData.tag_name === "string"
      ? releaseData.tag_name
      : "latest";
    const releaseName = releaseData && typeof releaseData.name === "string"
      ? releaseData.name
      : "Latest stable build";
    const publishedAt = releaseData ? releaseData.published_at : null;
    const asset = pickPreferredAsset(releaseData ? releaseData.assets : null);

    setText(releaseVersionEl, version);
    setText(releaseTitleEl, releaseName);
    setText(releaseDateEl, formatDate(publishedAt));
    if (releaseDateEl && publishedAt) {
      releaseDateEl.setAttribute("datetime", publishedAt);
    }

    if (asset && asset.name) {
      setText(releaseArtifactEl, asset.name);
      setText(releaseSizeEl, formatFileSize(asset.size));
      setText(releaseDownloadCountEl, formatNumber(asset.download_count || 0));
      applyDownloadUrl(asset.browser_download_url);
    } else {
      setText(releaseArtifactEl, "No DMG asset detected");
      setText(releaseSizeEl, "-");
      setText(releaseDownloadCountEl, "-");
      applyDownloadUrl(releaseData ? releaseData.html_url : fallbackReleaseUrl);
    }

    renderHighlights(extractHighlights(releaseData ? releaseData.body : ""));
    setHref(releaseNotesLinkEl, releaseData && releaseData.html_url ? releaseData.html_url : fallbackReleaseUrl);
    setHref(releaseHistoryLinkEl, fallbackReleaseHistoryUrl);

    if (version && primaryDownloadEl) {
      primaryDownloadEl.textContent = "Download " + version;
    }

    if (version && secondaryDownloadEl) {
      secondaryDownloadEl.textContent = "Download " + version;
    }

    if (sourceLabel === "cache") {
      return;
    }
  }

  function applyRepoStats(repoData, sourceLabel) {
    const stars = repoData && Number.isFinite(repoData.stargazers_count)
      ? repoData.stargazers_count
      : null;
    const repoUrl = repoData && typeof repoData.html_url === "string"
      ? repoData.html_url
      : fallbackRepoUrl;

    setHref(githubStarsLinkEl, repoUrl);
    if (stars !== null) {
      const starsText = formatNumber(stars);
      setText(githubStarsCountEl, starsText);
      if (githubStarsLinkEl) {
        githubStarsLinkEl.setAttribute("aria-label", "GitHub stars: " + starsText);
      }
    }

    if (sourceLabel === "cache" && githubStarsLinkEl) {
      githubStarsLinkEl.title = "GitHub stars (cached)";
    }
  }

  function readCache(cacheKey, maxAgeMs) {
    try {
      const raw = localStorage.getItem(cacheKey);
      if (!raw) {
        return null;
      }

      const parsed = JSON.parse(raw);
      if (!parsed || !parsed.savedAt || !parsed.data) {
        return null;
      }

      if (Date.now() - parsed.savedAt > maxAgeMs) {
        return null;
      }

      return parsed.data;
    } catch (_error) {
      return null;
    }
  }

  function saveCache(cacheKey, data) {
    try {
      localStorage.setItem(
        cacheKey,
        JSON.stringify({
          savedAt: Date.now(),
          data: data
        })
      );
    } catch (_error) {
      // Ignore storage write failures.
    }
  }

  async function loadLatestRelease() {
    applyDownloadUrl(fallbackReleaseUrl);

    const cached = readCache(releaseCacheKey, releaseCacheMaxAgeMs);
    if (cached) {
      applyReleaseData(cached, "cache");
    }

    try {
      const response = await fetch(releaseApiUrl, {
        headers: {
          Accept: "application/vnd.github+json"
        }
      });

      if (!response.ok) {
        throw new Error("GitHub API request failed with status " + response.status);
      }

      const data = await response.json();
      applyReleaseData(data, "live");
      saveCache(releaseCacheKey, data);
    } catch (error) {
      if (!cached) {
        setText(releaseVersionEl, "latest");
        setText(releaseTitleEl, "Could not load release data");
        setText(releaseDateEl, "Unavailable");
        setText(releaseArtifactEl, "Open release page");
        setText(releaseSizeEl, "-");
        setText(releaseDownloadCountEl, "-");
        renderHighlights([]);
      } else {
      }

      if (error && error.message) {
        console.warn("[CiteBar website]", error.message);
      }
    }
  }

  async function loadRepoStats() {
    const cached = readCache(repoCacheKey, repoCacheMaxAgeMs);
    if (cached) {
      applyRepoStats(cached, "cache");
    }

    try {
      const response = await fetch(repoApiUrl, {
        headers: {
          Accept: "application/vnd.github+json"
        }
      });

      if (!response.ok) {
        throw new Error("GitHub repo API request failed with status " + response.status);
      }

      const data = await response.json();
      applyRepoStats(data, "live");
      saveCache(repoCacheKey, data);
    } catch (error) {
      if (!cached && githubStarsCountEl) {
        githubStarsCountEl.textContent = "-";
      }

      if (error && error.message) {
        console.warn("[CiteBar website]", error.message);
      }
    }
  }

  async function copyCommand() {
    if (!commandEl || !copyButtonEl) {
      return;
    }

    const command = commandEl.textContent ? commandEl.textContent.trim() : "";
    if (!command) {
      return;
    }

    let copied = false;

    if (navigator.clipboard && navigator.clipboard.writeText) {
      try {
        await navigator.clipboard.writeText(command);
        copied = true;
      } catch (_error) {
        copied = false;
      }
    }

    if (!copied) {
      const input = document.createElement("textarea");
      input.value = command;
      input.setAttribute("readonly", "readonly");
      input.style.position = "absolute";
      input.style.left = "-9999px";
      document.body.appendChild(input);
      input.select();
      copied = document.execCommand("copy");
      document.body.removeChild(input);
    }

    if (copied) {
      setText(copyStatusEl, "Copied.");
      copyButtonEl.classList.add("copied");
      setTimeout(function () {
        setText(copyStatusEl, "");
        copyButtonEl.classList.remove("copied");
      }, 1200);
    } else {
      setText(copyStatusEl, "Copy failed. Please copy manually.");
    }
  }

  if (copyButtonEl) {
    copyButtonEl.addEventListener("click", copyCommand);
  }

  loadLatestRelease();
  loadRepoStats();
})();
