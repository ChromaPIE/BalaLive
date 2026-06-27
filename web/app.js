(function () {
  "use strict";

  const root = document.getElementById("balalive");
  const panel = document.getElementById("balalive-panel");
  const title = document.getElementById("balalive-title");
  const list = document.getElementById("balalive-list");

  const PANELS = [
    { id: "jokers", fallback: "JOKERS", secondsKey: "joker_seconds" },
    { id: "consumables", fallback: "CONSUMABLES", secondsKey: "consumable_seconds" },
    { id: "hands", fallback: "HANDS", secondsKey: "hand_seconds" }
  ];

  let state = null;
  let activeIndex = 0;
  let rotationTimer = null;
  let reconnectTimer = null;
  let switching = false;
  let standbyActive = true;
  let switchToken = 0;

  function inRun() {
    return state && state.in_run !== false;
  }

  function panelLabel(panelDef) {
    const labels = state && state.labels;
    return labels && labels[panelDef.id] ? labels[panelDef.id] : panelDef.fallback;
  }

  function standbyLabel() {
    const labels = state && state.labels;
    return labels && labels.standby ? labels.standby : "BALALIVE";
  }

  function panelState(panelId) {
    return state && state[panelId] && Array.isArray(state[panelId].items)
      ? state[panelId].items
      : [];
  }

  function dwellMs(panelDef) {
    const seconds = Number(state && state.config && state.config[panelDef.secondsKey]);
    return Math.max(1, Number.isFinite(seconds) ? seconds : 5) * 1000;
  }

  function itemValue(item, panelId) {
    if (panelId === "hands") {
      return "Lv." + String(item.level || 1);
    }
    return item.count && item.count > 1 ? "X" + String(item.count) : "";
  }

  function itemSignature(item, panelId) {
    return [
      item.name || "",
      itemValue(item, panelId),
      item.rarity_key || "",
      item.rarity_color || ""
    ].join("|");
  }

  function createItem(item, panelId, animate) {
    const element = document.createElement("li");
    element.className = "balalive-item";
    element.dataset.key = item.id || item.key || item.name || "";
    element.dataset.signature = itemSignature(item, panelId);

    if (item.rarity_class) {
      element.classList.add(item.rarity_class);
    }
    if (item.rarity_color) {
      element.style.setProperty("--rarity-color", item.rarity_color);
    }

    const name = document.createElement("span");
    name.className = "balalive-name";
    name.textContent = item.name || item.key || "";
    element.appendChild(name);

    const value = itemValue(item, panelId);
    if (value) {
      const suffix = document.createElement("span");
      suffix.className = panelId === "hands" ? "balalive-level" : "balalive-count";
      suffix.textContent = value;
      element.appendChild(suffix);
    }

    if (animate) {
      element.classList.add("balalive-item-enter");
      window.setTimeout(() => element.classList.remove("balalive-item-enter"), 220);
    }

    return element;
  }

  function updateItem(element, item, panelId) {
    const nextSignature = itemSignature(item, panelId);
    if (element.dataset.signature === nextSignature) return;

    const replacement = createItem(item, panelId, false);
    element.className = replacement.className;
    element.style.cssText = replacement.style.cssText;
    element.dataset.signature = nextSignature;
    element.replaceChildren(...Array.from(replacement.childNodes));
    element.classList.add("balalive-item-pulse");
    window.setTimeout(() => element.classList.remove("balalive-item-pulse"), 260);
  }

  function measureItems() {
    const positions = new Map();
    Array.from(list.children).forEach((child) => {
      positions.set(child.dataset.key, child.getBoundingClientRect());
    });
    return positions;
  }

  function animateMovedItems(previousPositions) {
    if (!previousPositions || previousPositions.size < 2) return;

    Array.from(list.children).forEach((child) => {
      if (child.classList.contains("balalive-item-enter")) return;
      if (child.classList.contains("balalive-item-exit")) return;
      if (child.classList.contains("balalive-item-pulse")) return;

      const previous = previousPositions.get(child.dataset.key);
      if (!previous) return;

      const current = child.getBoundingClientRect();
      const dx = previous.left - current.left;
      const dy = previous.top - current.top;
      if (Math.abs(dx) < 0.5 && Math.abs(dy) < 0.5) return;

      child.style.setProperty("--balalive-move-x", dx + "px");
      child.style.setProperty("--balalive-move-y", dy + "px");
      child.classList.remove("balalive-item-move");
      void child.offsetWidth;
      child.classList.add("balalive-item-move");

      window.setTimeout(() => {
        child.classList.remove("balalive-item-move");
        child.style.removeProperty("--balalive-move-x");
        child.style.removeProperty("--balalive-move-y");
      }, 260);
    });
  }

  function renderList(panelDef, animateNew) {
    const previousPositions = measureItems();
    const items = panelState(panelDef.id);
    const existing = new Map();

    Array.from(list.children).forEach((child) => {
      existing.set(child.dataset.key, child);
    });

    const nextKeys = new Set();
    items.forEach((item) => {
      const key = item.id || item.key || item.name || "";
      nextKeys.add(key);
      let current = existing.get(key);
      if (current) {
        updateItem(current, item, panelDef.id);
      } else {
        current = createItem(item, panelDef.id, animateNew);
      }
      list.appendChild(current);
    });

    existing.forEach((child, key) => {
      if (nextKeys.has(key)) return;
      child.classList.add("balalive-item-exit");
      window.setTimeout(() => {
        if (child.parentNode) child.parentNode.removeChild(child);
      }, 190);
    });

    animateMovedItems(previousPositions);
  }

  function finishPanelSwap() {
    window.requestAnimationFrame(() => {
      panel.classList.remove("is-entering");
      switching = false;
    });
  }

  function showStandby(animate) {
    window.clearTimeout(rotationTimer);
    root.classList.add("is-standby");

    if (standbyActive || !animate || switching) {
      switchToken += 1;
      panel.classList.remove("is-leaving");
      panel.classList.remove("is-entering");
      switching = false;
      standbyActive = true;
      panel.dataset.panel = "standby";
      title.textContent = standbyLabel();
      list.replaceChildren();
      return;
    }

    switching = true;
    const token = ++switchToken;
    panel.classList.add("is-leaving");
    window.setTimeout(() => {
      if (token !== switchToken) return;
      if (inRun()) {
        panel.classList.remove("is-leaving");
        root.classList.remove("is-standby");
        switching = false;
        renderList(PANELS[activeIndex], false);
        scheduleRotation();
        return;
      }

      standbyActive = true;
      panel.dataset.panel = "standby";
      title.textContent = standbyLabel();
      list.replaceChildren();
      panel.classList.remove("is-leaving");
      panel.classList.add("is-entering");
      finishPanelSwap();
    }, 220);
  }

  function applyState(nextState) {
    state = nextState || {};
    const style = state.config && state.config.joker_rarity_style === "background"
      ? "background"
      : "text";
    root.classList.toggle("joker-rarity-background", style === "background");
    root.classList.toggle("joker-rarity-text", style !== "background");

    if (!inRun()) {
      showStandby(true);
      return;
    }

    const panelDef = PANELS[activeIndex];
    if (standbyActive) {
      showPanel(activeIndex, true);
      return;
    }

    root.classList.remove("is-standby");
    title.textContent = panelLabel(panelDef);
    renderList(panelDef, false);
    scheduleRotation();
  }

  function showPanel(index, animateAll) {
    if (!state || !inRun() || switching) return;
    switching = true;
    root.classList.remove("is-standby");

    const nextIndex = index % PANELS.length;
    const panelDef = PANELS[nextIndex];
    const token = ++switchToken;
    panel.classList.add("is-leaving");

    window.setTimeout(() => {
      if (token !== switchToken) return;
      if (!inRun()) {
        panel.classList.remove("is-leaving");
        switching = false;
        showStandby(false);
        return;
      }

      standbyActive = false;
      activeIndex = nextIndex;
      panel.dataset.panel = panelDef.id;
      title.textContent = panelLabel(panelDef);
      list.replaceChildren();
      panel.classList.remove("is-leaving");
      panel.classList.add("is-entering");
      renderList(panelDef, animateAll);
      finishPanelSwap();
      scheduleRotation();
    }, 220);
  }

  function scheduleRotation() {
    window.clearTimeout(rotationTimer);
    if (!state || !inRun() || standbyActive) return;
    rotationTimer = window.setTimeout(() => {
      showPanel(activeIndex + 1, true);
    }, dwellMs(PANELS[activeIndex]));
  }

  function fetchStateFallback() {
    window.clearTimeout(reconnectTimer);
    reconnectTimer = window.setTimeout(() => {
      fetch("/state.json", { cache: "no-store" })
        .then((response) => response.ok ? response.json() : null)
        .then((json) => {
          if (json) applyState(json);
        })
        .catch(() => {});
    }, 1000);
  }

  function connectEvents() {
    if (!("EventSource" in window)) {
      fetchStateFallback();
      return;
    }

    const source = new EventSource("/events");
    source.addEventListener("state", (event) => {
      try {
        applyState(JSON.parse(event.data));
      } catch (error) {
        fetchStateFallback();
      }
    });
    source.onerror = fetchStateFallback;
  }

  title.textContent = "BALALIVE";
  connectEvents();
})();
