const displayEl = document.getElementById("display");
const expressionEl = document.getElementById("expression");
const historyListEl = document.getElementById("historyList");
const clearHistoryBtn = document.getElementById("clearHistory");
const clearHistoryLabel = document.getElementById("clearHistoryLabel");
const menuButton = document.getElementById("menuButton");
const appMenu = document.getElementById("appMenu");
const shortcutsOption = document.getElementById("shortcutsOption");
const shortcutPanel = document.getElementById("shortcutPanel");
const closeShortcutsBtn = document.getElementById("closeShortcuts");
const panelMoreButton = document.getElementById("panelMoreButton");
const tabButtons = Array.from(document.querySelectorAll(".tab"));

const OPERATORS = {
  add: "+",
  subtract: "\u2212",
  multiply: "\u00d7",
  divide: "\u00f7"
};

const formatter = new Intl.NumberFormat("en-IN", {
  maximumFractionDigits: 10
});

const operatorFns = {
  [OPERATORS.add]: (a, b) => a + b,
  [OPERATORS.subtract]: (a, b) => a - b,
  [OPERATORS.multiply]: (a, b) => a * b,
  [OPERATORS.divide]: (a, b) => a / b
};

let currentValue = "";
let storedValue = null;
let pendingOperator = null;
let waitingForNextValue = false;
let lastExpression = "";
let memoryValue = null;
let memoryHistory = [];
let activeTab = "history";
let history = [];

function hasValue() {
  return currentValue !== "" && currentValue !== "Error";
}

function parseCurrent() {
  return hasValue() ? Number(currentValue) : 0;
}

function formatNumber(value) {
  if (!Number.isFinite(value)) {
    return "Error";
  }

  const normalized = Object.is(value, -0) ? 0 : value;
  return formatter.format(normalized);
}

function compactNumber(value) {
  if (!Number.isFinite(value)) {
    return "Error";
  }

  const normalized = Object.is(value, -0) ? 0 : value;
  return Number.parseFloat(normalized.toFixed(10)).toString();
}

function displayOperand(value) {
  return formatNumber(Number(value));
}

function updateDisplay() {
  expressionEl.textContent = lastExpression;

  if (currentValue === "") {
    displayEl.textContent = "";
    return;
  }

  displayEl.textContent = currentValue === "Error"
    ? "Error"
    : formatNumber(parseCurrent());
}

function setActiveTab(tabName) {
  activeTab = tabName;

  tabButtons.forEach((button) => {
    const buttonTab = button.textContent.trim().toLowerCase();
    button.classList.toggle("active", buttonTab === tabName);
  });

  clearHistoryLabel.textContent = tabName === "memory"
    ? "Clear Memory"
    : "Clear History";

  renderSidePanel();
}

function createSidePanelRow(item) {
  const row = document.createElement("article");
  row.className = "history-item";

  const expression = document.createElement("div");
  expression.className = "history-expression";
  expression.textContent = item.expression;

  const result = document.createElement("div");
  result.className = "history-result";
  result.textContent = item.result;

  const icon = document.createElement("span");
  icon.className = "copy-icon";
  icon.setAttribute("aria-hidden", "true");

  row.append(expression, result, icon);
  return row;
}

function createEmptyState(message) {
  const empty = document.createElement("div");
  empty.className = "empty-state";
  empty.textContent = message;
  return empty;
}

function renderSidePanel() {
  historyListEl.innerHTML = "";

  if (activeTab === "memory") {
    if (memoryHistory.length === 0) {
      historyListEl.appendChild(createEmptyState("No memory stored"));
      return;
    }

    memoryHistory.forEach((item) => {
      historyListEl.appendChild(createSidePanelRow(item));
    });
    return;
  }

  if (history.length === 0) {
    historyListEl.appendChild(createEmptyState("No history yet"));
    return;
  }

  history.forEach((item) => {
    historyListEl.appendChild(createSidePanelRow(item));
  });
}

function setMenuOpen(isOpen) {
  appMenu.hidden = !isOpen;
  menuButton.setAttribute("aria-expanded", String(isOpen));
}

function setShortcutsOpen(isOpen) {
  shortcutPanel.hidden = !isOpen;
  if (isOpen) {
    setMenuOpen(false);
  }
}

function resetCalculator() {
  currentValue = "";
  storedValue = null;
  pendingOperator = null;
  waitingForNextValue = false;
  lastExpression = "";
  updateDisplay();
}

function inputNumber(number) {
  if (currentValue === "Error" || waitingForNextValue) {
    currentValue = number;
    waitingForNextValue = false;
  } else {
    currentValue = currentValue === "0" ? number : currentValue + number;
  }

  lastExpression = pendingOperator && storedValue !== null
    ? `${displayOperand(storedValue)} ${pendingOperator}`
    : "";
  updateDisplay();
}

function inputDecimal() {
  if (currentValue === "Error" || waitingForNextValue || currentValue === "") {
    currentValue = "0.";
    waitingForNextValue = false;
  } else if (!currentValue.includes(".")) {
    currentValue += ".";
  }

  updateDisplay();
}

function chooseOperator(operator) {
  if (!hasValue()) {
    return;
  }

  const inputValue = parseCurrent();

  if (pendingOperator && !waitingForNextValue) {
    const result = calculate(storedValue, inputValue, pendingOperator);
    if (result === null) {
      return;
    }
    storedValue = result;
    currentValue = compactNumber(result);
  } else {
    storedValue = inputValue;
  }

  pendingOperator = operator;
  waitingForNextValue = true;
  lastExpression = `${displayOperand(storedValue)} ${operator}`;
  updateDisplay();
}

function calculate(first, second, operator) {
  if (operator === OPERATORS.divide && second === 0) {
    currentValue = "Error";
    storedValue = null;
    pendingOperator = null;
    waitingForNextValue = true;
    lastExpression = "";
    updateDisplay();
    return null;
  }

  return operatorFns[operator](first, second);
}

function addToHistory(expression, result) {
  history.unshift({
    expression,
    result: formatNumber(result)
  });
  history = history.slice(0, 5);

  if (activeTab === "history") {
    renderSidePanel();
  }
}

function addToMemoryHistory(expression) {
  if (memoryValue === null) {
    return;
  }

  memoryHistory.unshift({
    expression,
    result: formatNumber(memoryValue)
  });
  memoryHistory = memoryHistory.slice(0, 5);
}

function completeCalculation() {
  if (!pendingOperator || storedValue === null || !hasValue()) {
    return;
  }

  const secondValue = parseCurrent();
  const expression = `${displayOperand(storedValue)} ${pendingOperator} ${displayOperand(secondValue)} =`;
  const result = calculate(storedValue, secondValue, pendingOperator);

  if (result === null) {
    return;
  }

  currentValue = compactNumber(result);
  lastExpression = expression;
  storedValue = null;
  pendingOperator = null;
  waitingForNextValue = true;

  addToHistory(expression, result);
  updateDisplay();
}

function backspace() {
  if (currentValue === "Error" || waitingForNextValue) {
    currentValue = "";
    waitingForNextValue = false;
  } else {
    currentValue = currentValue.length > 1 ? currentValue.slice(0, -1) : "";
  }

  updateDisplay();
}

function applyUnary(action) {
  if (!hasValue()) {
    return;
  }

  const value = parseCurrent();
  let result = value;
  let expression = "";

  if (action === "percent") {
    result = value / 100;
    expression = `${displayOperand(value)}% =`;
  }

  if (action === "reciprocal") {
    if (value === 0) {
      currentValue = "Error";
      lastExpression = "1 / 0 =";
      waitingForNextValue = true;
      updateDisplay();
      return;
    }
    result = 1 / value;
    expression = `1 / ${displayOperand(value)} =`;
  }

  if (action === "square") {
    result = value * value;
    expression = `${displayOperand(value)}\u00b2 =`;
  }

  if (action === "sqrt") {
    if (value < 0) {
      currentValue = "Error";
      lastExpression = `\u221a${displayOperand(value)} =`;
      waitingForNextValue = true;
      updateDisplay();
      return;
    }
    result = Math.sqrt(value);
    expression = `\u221a${displayOperand(value)} =`;
  }

  currentValue = compactNumber(result);
  lastExpression = expression;
  waitingForNextValue = true;

  addToHistory(expression, result);
  updateDisplay();
}

function toggleSign() {
  if (!hasValue() || currentValue === "0") {
    return;
  }

  currentValue = currentValue.startsWith("-")
    ? currentValue.slice(1)
    : `-${currentValue}`;
  updateDisplay();
}

function handleMemory(action) {
  const value = parseCurrent();

  if (action === "clear") {
    memoryValue = null;
    memoryHistory = [];
  }

  if (action === "recall" && memoryValue !== null) {
    currentValue = compactNumber(memoryValue);
    waitingForNextValue = true;
    lastExpression = "";
    updateDisplay();
  }

  if (action === "add") {
    memoryValue = (memoryValue ?? 0) + value;
    addToMemoryHistory(`M+ ${displayOperand(value)}`);
  }

  if (action === "subtract") {
    memoryValue = (memoryValue ?? 0) - value;
    addToMemoryHistory(`M− ${displayOperand(value)}`);
  }

  if (action === "store") {
    memoryValue = value;
    addToMemoryHistory("MS");
  }

  if (activeTab === "memory") {
    renderSidePanel();
  }
}

function normalizeOperator(operator) {
  if (operator === "x" || operator === "X" || operator === "*") {
    return OPERATORS.multiply;
  }

  if (operator === "/") {
    return OPERATORS.divide;
  }

  if (operator === "-") {
    return OPERATORS.subtract;
  }

  return operator;
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("button");
  if (!button) {
    setMenuOpen(false);
    return;
  }

  if (button === menuButton) {
    setMenuOpen(appMenu.hidden);
    return;
  }

  if (button === shortcutsOption || button === panelMoreButton) {
    setShortcutsOpen(true);
    return;
  }

  if (button === closeShortcutsBtn) {
    setShortcutsOpen(false);
    return;
  }

  if (button.classList.contains("tab")) {
    setActiveTab(button.textContent.trim().toLowerCase());
    return;
  }

  if (button.dataset.number) {
    inputNumber(button.dataset.number);
  }

  if (button.dataset.operator) {
    chooseOperator(normalizeOperator(button.dataset.operator));
  }

  const action = button.dataset.action;
  if (action === "decimal") inputDecimal();
  if (action === "clear" || action === "clear-entry") resetCalculator();
  if (action === "backspace") backspace();
  if (action === "equals") completeCalculation();
  if (action === "toggle-sign") toggleSign();
  if (["percent", "reciprocal", "square", "sqrt"].includes(action)) applyUnary(action);

  if (button.dataset.memory) {
    handleMemory(button.dataset.memory);
  }

  if (!appMenu.contains(button)) {
    setMenuOpen(false);
  }
});

clearHistoryBtn.addEventListener("click", () => {
  if (activeTab === "memory") {
    memoryValue = null;
  } else {
    history = [];
  }

  renderSidePanel();
});

window.addEventListener("keydown", (event) => {
  const key = event.key;

  if (/^\d$/.test(key)) {
    inputNumber(key);
    return;
  }

  if (key === ".") {
    inputDecimal();
    return;
  }

  if (key === "Backspace") {
    backspace();
    return;
  }

  if (key === "Enter" || key === "=") {
    event.preventDefault();
    completeCalculation();
    return;
  }

  if (key === "Escape" || key.toLowerCase() === "c") {
    if (!shortcutPanel.hidden) {
      setShortcutsOpen(false);
      return;
    }
    resetCalculator();
    return;
  }

  if (["+", "-", "*", "/", "x", "X"].includes(key)) {
    event.preventDefault();
    chooseOperator(normalizeOperator(key));
    return;
  }

  if (key === "%") {
    applyUnary("percent");
    return;
  }

  if (key.toLowerCase() === "m") {
    setActiveTab(activeTab === "memory" ? "history" : "memory");
  }
});

updateDisplay();
renderSidePanel();
