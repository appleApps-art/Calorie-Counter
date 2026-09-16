export function isAsciiFoodQuery(query) {
  return /^[a-zA-Z0-9\s\-'&.,+/()%]+$/.test(String(query || ""));
}

export function shouldTranslateFoodQuery(query) {
  if (!query) return false;
  return !isAsciiFoodQuery(query);
}

export function cleanDishTitle(title) {
  return String(title || "")
    .trim()
    .replace(/^["«»']+|["«»']+$/g, "")
    .replace(/\s+/g, " ");
}

export function polishSearchRecipeTitle(title) {
  const original = cleanDishTitle(title);
  if (!original) return "";
  let cut = original.split(/\s*[|:–—]\s*/)[0];
  cut = cut.replace(/\s*[-–—]\s*(рецепт(?:и|ів)?|recipes?).*$/i, "");
  cut = cut.replace(
    /^(?:how\s+to\s+(?:cook|make|prepare|bake|fry|roast)|(?:easy\s+)?recipe(?:s)?\s+for|рецепт(?:и|ів)?(?:\s+(?:для|від))?)\s+/i,
    ""
  );
  cut = cut.replace(/\s+(рецепт(?:и|ів)?|recipes?)\s*$/i, "");
  cut = cleanDishTitle(cut);
  const dish = cut.split(/\s+/).filter(Boolean).slice(0, 8).join(" ");
  const next = dish || original;
  return next.charAt(0).toLocaleUpperCase() + next.slice(1);
}

export function applySearchTitleMap(pending, map) {
  if (!map) return;
  for (const { item, title } of pending) {
    if (!Object.prototype.hasOwnProperty.call(map, title)) continue;
    const rewritten = cleanDishTitle(map[title] || "");
    if (!rewritten) continue;
    item.title = rewritten;
    item.name = rewritten;
  }
}

export function spoonacularRecipeImageURL(id, image) {
  const fromApi = String(image || "").trim();
  if (/^https?:\/\//i.test(fromApi) && !isPlaceholderSearchImage(fromApi)) {
    return fromApi;
  }
  const numeric = String(id ?? "").replace(/\D/g, "");
  if (!numeric) return fromApi;
  return `https://img.spoonacular.com/recipes/${numeric}-636x393.jpg`;
}

export function isCompleteSearchRecipe(item) {
  return Boolean(String(item?.title || item?.name || "").trim() && String(item?.imageURL || "").trim());
}

function isPlaceholderSearchImage(value) {
  const url = String(value || "").trim().toLowerCase();
  if (!url) return true;
  return (
    url.includes("placeholder") ||
    url.includes("no-image") ||
    url.includes("missing-image") ||
    url.includes("favicon") ||
    url.includes(".svg") ||
    /ingredients_100x100\/?$/.test(url)
  );
}
