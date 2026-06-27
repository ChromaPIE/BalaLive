(function () {
  "use strict";

  const root = document.getElementById("balalive");
  const panel = document.getElementById("balalive-panel");
  const title = document.getElementById("balalive-title");
  const list = document.getElementById("balalive-list");

  const PANELS = [
    { id: "jokers", label: "Jokers", secondsKey: "joker_seconds" },
    { id: "consumables", label: "Consumables", secondsKey: "consumable_seconds" },
    { id: "hands", label: "Hands", secondsKey: "hand_seconds" }
  ];

  let state = null;
  let activeIndex = 0;
  let rotationTimer = null;
  let reconnectTimer = null;
  let switching = false;

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

  function renderList(panelDef, animateNew) {
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

  }

  function applyState(nextState) {
    state = nextState || {};
    const style = state.config && state.config.joker_rarity_style === "background"
      ? "background"
      : "text";
    root.classList.toggle("joker-rarity-background", style === "background");
    root.classList.toggle("joker-rarity-text", style !== "background");

    const panelDef = PANELS[activeIndex];
    renderList(panelDef, false);
    scheduleRotation();
  }

  function showPanel(index, animateAll) {
    if (!state || switching) return;
    switching = true;

    const nextIndex = index % PANELS.length;
    const panelDef = PANELS[nextIndex];
    panel.classList.add("is-leaving");

    window.setTimeout(() => {
      activeIndex = nextIndex;
      panel.dataset.panel = panelDef.id;
      title.textContent = panelDef.label;
      list.replaceChildren();
      panel.classList.remove("is-leaving");
      panel.classList.add("is-entering");
      renderList(panelDef, animateAll);
      window.requestAnimationFrame(() => {
        panel.classList.remove("is-entering");
        switching = false;
      });
      scheduleRotation();
    }, 220);
  }

  function scheduleRotation() {
    window.clearTimeout(rotationTimer);
    if (!state) return;
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

  title.textContent = PANELS[0].label;
  connectEvents();
})();
