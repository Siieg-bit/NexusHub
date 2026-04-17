import { useState, useEffect, useRef, useCallback } from "react";
import { supabase, StoreItem, StoreItemType, Rarity } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  Plus,
  Trash2,
  Pencil,
  CheckCircle2,
  AlertCircle,
  Loader2,
  RefreshCw,
  Search,
  Upload,
  X,
  Save,
  ShoppingBag,
  Filter,
} from "lucide-react";

const TYPE_LABELS: Record<StoreItemType, string> = {
  avatar_frame: "Moldura de Avatar",
  chat_bubble: "Chat Bubble",
  sticker_pack: "Pack de Stickers",
  profile_background: "Fundo de Perfil",
  chat_background: "Fundo de Chat",
};

const RARITY_COLORS: Record<Rarity, string> = {
  common: "#9CA3AF",
  rare: "#60A5FA",
  epic: "#A78BFA",
  legendary: "#FBBF24",
};

const RARITY_LABELS: Record<Rarity, string> = {
  common: "Comum",
  rare: "Raro",
  epic: "Épico",
  legendary: "Lendário",
};

type ItemForm = {
  name: string;
  description: string;
  type: StoreItemType;
  price_coins: number;
  price_real_cents: number | null;
  is_premium_only: boolean;
  is_limited_edition: boolean;
  is_active: boolean;
  sort_order: number;
  rarity: Rarity;
  tags: string;
};

const DEFAULT_FORM: ItemForm = {
  name: "",
  description: "",
  type: "chat_bubble",
  price_coins: 150,
  price_real_cents: null,
  is_premium_only: false,
  is_limited_edition: false,
  is_active: true,
  sort_order: 0,
  rarity: "common",
  tags: "",
};

export default function StoreItemsPage() {
  const [items, setItems] = useState<StoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [filterType, setFilterType] = useState<StoreItemType | "all">("all");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");

  const [showForm, setShowForm] = useState(false);
  const [editingItem, setEditingItem] = useState<StoreItem | null>(null);
  const [form, setForm] = useState<ItemForm>(DEFAULT_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  // Upload
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [assetFile, setAssetFile] = useState<File | null>(null);
  const [assetUrl, setAssetUrl] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const previewInputRef = useRef<HTMLInputElement>(null);
  const assetInputRef = useRef<HTMLInputElement>(null);

  async function loadItems() {
    setLoading(true);
    const { data, error } = await supabase
      .from("store_items")
      .select("*")
      .order("sort_order", { ascending: true });
    if (!error && data) setItems(data as StoreItem[]);
    setLoading(false);
  }

  useEffect(() => {
    loadItems();
  }, []);

  function openCreate() {
    setEditingItem(null);
    setForm(DEFAULT_FORM);
    setPreviewFile(null);
    setPreviewUrl(null);
    setAssetFile(null);
    setAssetUrl(null);
    setShowForm(true);
  }

  function openEdit(item: StoreItem) {
    setEditingItem(item);
    setForm({
      name: item.name,
      description: item.description ?? "",
      type: item.type,
      price_coins: item.price_coins,
      price_real_cents: item.price_real_cents,
      is_premium_only: item.is_premium_only,
      is_limited_edition: item.is_limited_edition,
      is_active: item.is_active,
      sort_order: item.sort_order,
      rarity: item.rarity ?? "common",
      tags: (item.tags ?? []).join(", "),
    });
    setPreviewUrl(item.preview_url);
    setAssetUrl(item.asset_url);
    setPreviewFile(null);
    setAssetFile(null);
    setShowForm(true);
  }

  function closeForm() {
    setShowForm(false);
    setEditingItem(null);
  }

  async function uploadFile(file: File, path: string): Promise<string | null> {
    const { data, error } = await supabase.storage
      .from("store-assets")
      .upload(path, file, { upsert: true });
    if (error) {
      toast.error(`Erro no upload: ${error.message}`);
      return null;
    }
    const { data: urlData } = supabase.storage
      .from("store-assets")
      .getPublicUrl(data.path);
    return urlData.publicUrl;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) {
      toast.error("Nome é obrigatório.");
      return;
    }
    setSubmitting(true);
    try {
      let finalPreviewUrl = previewUrl;
      let finalAssetUrl = assetUrl;

      // Upload preview
      if (previewFile) {
        const ext = previewFile.name.split(".").pop();
        const path = `previews/${Date.now()}_${form.name.replace(/\s+/g, "_")}.${ext}`;
        finalPreviewUrl = await uploadFile(previewFile, path);
        if (!finalPreviewUrl) return;
      }

      // Upload asset
      if (assetFile) {
        const ext = assetFile.name.split(".").pop();
        const path = `assets/${form.type}/${Date.now()}_${form.name.replace(/\s+/g, "_")}.${ext}`;
        finalAssetUrl = await uploadFile(assetFile, path);
        if (!finalAssetUrl) return;
      }

      const payload = {
        name: form.name.trim(),
        description: form.description.trim(),
        type: form.type,
        price_coins: form.price_coins,
        price_real_cents: form.price_real_cents,
        is_premium_only: form.is_premium_only,
        is_limited_edition: form.is_limited_edition,
        is_active: form.is_active,
        sort_order: form.sort_order,
        rarity: form.rarity,
        tags: form.tags
          .split(",")
          .map((t) => t.trim())
          .filter(Boolean),
        preview_url: finalPreviewUrl,
        asset_url: finalAssetUrl,
      };

      if (editingItem) {
        const { error } = await supabase
          .from("store_items")
          .update(payload)
          .eq("id", editingItem.id);
        if (error) throw error;
        toast.success("Item atualizado com sucesso!");
      } else {
        const { error } = await supabase.from("store_items").insert(payload);
        if (error) throw error;
        toast.success("Item criado com sucesso!");
      }

      closeForm();
      loadItems();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(`Erro: ${msg}`);
    } finally {
      setSubmitting(false);
    }
  }

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase
      .from("store_items")
      .update({ is_active: !item.is_active })
      .eq("id", item.id);
    if (error) {
      toast.error("Erro ao alterar status.");
    } else {
      toast.success(item.is_active ? "Item desativado." : "Item ativado!");
      loadItems();
    }
  }

  async function deleteItem(item: StoreItem) {
    if (!confirm(`Excluir "${item.name}"? Esta ação não pode ser desfeita.`))
      return;
    setDeletingId(item.id);
    const { error } = await supabase
      .from("store_items")
      .delete()
      .eq("id", item.id);
    if (error) {
      toast.error("Erro ao excluir item.");
    } else {
      toast.success("Item excluído.");
      loadItems();
    }
    setDeletingId(null);
  }

  function handleFileChange(
    file: File,
    type: "preview" | "asset"
  ) {
    if (!file.type.startsWith("image/")) {
      toast.error("Envie uma imagem válida.");
      return;
    }
    const reader = new FileReader();
    reader.onload = (e) => {
      if (type === "preview") {
        setPreviewFile(file);
        setPreviewUrl(e.target?.result as string);
      } else {
        setAssetFile(file);
        setAssetUrl(e.target?.result as string);
      }
    };
    reader.readAsDataURL(file);
  }

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFileChange(file, "preview");
  }, []);

  // Filtered items
  const filtered = items.filter((item) => {
    const matchSearch =
      !search ||
      item.name.toLowerCase().includes(search.toLowerCase()) ||
      (item.description ?? "").toLowerCase().includes(search.toLowerCase());
    const matchType = filterType === "all" || item.type === filterType;
    const matchStatus =
      filterStatus === "all" ||
      (filterStatus === "active" && item.is_active) ||
      (filterStatus === "inactive" && !item.is_active);
    return matchSearch && matchType && matchStatus;
  });

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-white">Produtos da Loja</h1>
          <p className="text-[#6B7280] text-sm mt-0.5">
            {items.length} itens cadastrados
          </p>
        </div>
        <Button
          onClick={openCreate}
          className="bg-[#E040FB] hover:bg-[#D030EB] text-white h-9 px-4 text-sm"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          Novo Item
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-5">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4B5563]" />
          <Input
            placeholder="Buscar por nome..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
          />
        </div>
        <select
          value={filterType}
          onChange={(e) => setFilterType(e.target.value as StoreItemType | "all")}
          className="bg-[#1C1E22] border border-[#2A2D34] text-[#9CA3AF] text-sm rounded-md px-3 h-9 focus:outline-none focus:border-[#E040FB]"
        >
          <option value="all">Todos os tipos</option>
          {Object.entries(TYPE_LABELS).map(([k, v]) => (
            <option key={k} value={k}>
              {v}
            </option>
          ))}
        </select>
        <select
          value={filterStatus}
          onChange={(e) =>
            setFilterStatus(e.target.value as "all" | "active" | "inactive")
          }
          className="bg-[#1C1E22] border border-[#2A2D34] text-[#9CA3AF] text-sm rounded-md px-3 h-9 focus:outline-none focus:border-[#E040FB]"
        >
          <option value="all">Todos os status</option>
          <option value="active">Ativos</option>
          <option value="inactive">Inativos</option>
        </select>
        <Button
          variant="ghost"
          size="sm"
          onClick={loadItems}
          className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9"
        >
          <RefreshCw className="w-3.5 h-3.5" />
        </Button>
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex items-center justify-center h-48">
          <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-12 text-center">
          <ShoppingBag className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
          <p className="text-[#4B5563] text-sm">Nenhum item encontrado</p>
        </div>
      ) : (
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#2A2D34]">
                <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase tracking-wide">
                  Produto
                </th>
                <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase tracking-wide">
                  Tipo
                </th>
                <th className="text-left px-4 py-3 text-[#6B7280] text-xs font-medium uppercase tracking-wide">
                  Raridade
                </th>
                <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase tracking-wide">
                  Preço
                </th>
                <th className="text-center px-4 py-3 text-[#6B7280] text-xs font-medium uppercase tracking-wide">
                  Status
                </th>
                <th className="text-right px-4 py-3 text-[#6B7280] text-xs font-medium uppercase tracking-wide">
                  Ações
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2D34]">
              {filtered.map((item) => (
                <tr
                  key={item.id}
                  className="hover:bg-[#1F2126] transition-colors"
                >
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      {item.preview_url ? (
                        <img
                          src={item.preview_url}
                          alt={item.name}
                          className="w-8 h-8 rounded-md object-cover bg-[#2A2D34]"
                        />
                      ) : (
                        <div className="w-8 h-8 rounded-md bg-[#2A2D34] flex items-center justify-center">
                          <ShoppingBag className="w-4 h-4 text-[#4B5563]" />
                        </div>
                      )}
                      <div>
                        <p className="text-white text-sm font-medium">
                          {item.name}
                        </p>
                        {item.description && (
                          <p className="text-[#6B7280] text-xs truncate max-w-[200px]">
                            {item.description}
                          </p>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-[#9CA3AF] text-sm">
                      {TYPE_LABELS[item.type]}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className="text-xs font-medium px-2 py-0.5 rounded-full"
                      style={{
                        color: RARITY_COLORS[item.rarity ?? "common"],
                        background: `${RARITY_COLORS[item.rarity ?? "common"]}20`,
                        border: `1px solid ${RARITY_COLORS[item.rarity ?? "common"]}40`,
                      }}
                    >
                      {RARITY_LABELS[item.rarity ?? "common"]}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className="text-[#FBBF24] text-sm font-medium">
                      {item.price_coins} coins
                    </span>
                    {item.price_real_cents && (
                      <p className="text-[#6B7280] text-xs">
                        R${" "}
                        {(item.price_real_cents / 100).toFixed(2)}
                      </p>
                    )}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <button
                      onClick={() => toggleActive(item)}
                      className={`inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-full border transition-colors ${
                        item.is_active
                          ? "bg-[#4ADE80]/10 text-[#4ADE80] border-[#4ADE80]/30 hover:bg-[#4ADE80]/20"
                          : "bg-red-500/10 text-red-400 border-red-500/30 hover:bg-red-500/20"
                      }`}
                    >
                      {item.is_active ? (
                        <CheckCircle2 className="w-3 h-3" />
                      ) : (
                        <AlertCircle className="w-3 h-3" />
                      )}
                      {item.is_active ? "Ativo" : "Inativo"}
                    </button>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-1">
                      <button
                        onClick={() => openEdit(item)}
                        className="p-1.5 rounded-md text-[#4B5563] hover:text-[#E040FB] hover:bg-[#E040FB]/10 transition-colors"
                        title="Editar"
                      >
                        <Pencil className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => deleteItem(item)}
                        disabled={deletingId === item.id}
                        className="p-1.5 rounded-md text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors"
                        title="Excluir"
                      >
                        {deletingId === item.id ? (
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        ) : (
                          <Trash2 className="w-3.5 h-3.5" />
                        )}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Form Modal */}
      {showForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={closeForm}
          />
          <div className="relative bg-[#1C1E22] border border-[#2A2D34] rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-2xl">
            {/* Modal header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-[#2A2D34] sticky top-0 bg-[#1C1E22] z-10">
              <h2 className="font-bold text-white">
                {editingItem ? "Editar Item" : "Novo Item da Loja"}
              </h2>
              <button
                onClick={closeForm}
                className="p-1.5 rounded-md text-[#4B5563] hover:text-white hover:bg-[#2A2D34]"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5">
              {/* Name + Type */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">Nome *</Label>
                  <Input
                    value={form.name}
                    onChange={(e) =>
                      setForm({ ...form, name: e.target.value })
                    }
                    placeholder="Ex: Glow Bubble"
                    className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
                    required
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">Tipo *</Label>
                  <select
                    value={form.type}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        type: e.target.value as StoreItemType,
                      })
                    }
                    className="w-full bg-[#111214] border border-[#2A2D34] text-white text-sm rounded-md px-3 h-9 focus:outline-none focus:border-[#E040FB]"
                  >
                    {Object.entries(TYPE_LABELS).map(([k, v]) => (
                      <option key={k} value={k}>
                        {v}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Description */}
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs">Descrição</Label>
                <textarea
                  value={form.description}
                  onChange={(e) =>
                    setForm({ ...form, description: e.target.value })
                  }
                  placeholder="Descrição do item..."
                  rows={2}
                  className="w-full bg-[#111214] border border-[#2A2D34] text-white text-sm rounded-md px-3 py-2 focus:outline-none focus:border-[#E040FB] placeholder:text-[#4B5563] resize-none"
                />
              </div>

              {/* Price + Rarity */}
              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">
                    Preço (Coins)
                  </Label>
                  <Input
                    type="number"
                    min={0}
                    value={form.price_coins}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        price_coins: parseInt(e.target.value) || 0,
                      })
                    }
                    className="bg-[#111214] border-[#2A2D34] text-white h-9"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">
                    Preço Real (centavos)
                  </Label>
                  <Input
                    type="number"
                    min={0}
                    value={form.price_real_cents ?? ""}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        price_real_cents: e.target.value
                          ? parseInt(e.target.value)
                          : null,
                      })
                    }
                    placeholder="Opcional"
                    className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">Raridade</Label>
                  <select
                    value={form.rarity}
                    onChange={(e) =>
                      setForm({ ...form, rarity: e.target.value as Rarity })
                    }
                    className="w-full bg-[#111214] border border-[#2A2D34] text-white text-sm rounded-md px-3 h-9 focus:outline-none focus:border-[#E040FB]"
                  >
                    {Object.entries(RARITY_LABELS).map(([k, v]) => (
                      <option key={k} value={k}>
                        {v}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Tags + Sort */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">
                    Tags (separadas por vírgula)
                  </Label>
                  <Input
                    value={form.tags}
                    onChange={(e) =>
                      setForm({ ...form, tags: e.target.value })
                    }
                    placeholder="neon, glow, premium"
                    className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">
                    Ordem de Exibição
                  </Label>
                  <Input
                    type="number"
                    value={form.sort_order}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        sort_order: parseInt(e.target.value) || 0,
                      })
                    }
                    className="bg-[#111214] border-[#2A2D34] text-white h-9"
                  />
                </div>
              </div>

              {/* Checkboxes */}
              <div className="flex flex-wrap gap-4">
                {[
                  { key: "is_active", label: "Ativo na loja" },
                  { key: "is_premium_only", label: "Apenas Premium" },
                  { key: "is_limited_edition", label: "Edição Limitada" },
                ].map(({ key, label }) => (
                  <label
                    key={key}
                    className="flex items-center gap-2 cursor-pointer"
                  >
                    <input
                      type="checkbox"
                      checked={form[key as keyof ItemForm] as boolean}
                      onChange={(e) =>
                        setForm({ ...form, [key]: e.target.checked })
                      }
                      className="w-4 h-4 rounded border-[#2A2D34] bg-[#111214] accent-[#E040FB]"
                    />
                    <span className="text-[#9CA3AF] text-sm">{label}</span>
                  </label>
                ))}
              </div>

              {/* Preview image upload */}
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs">
                  Imagem de Preview
                </Label>
                <div
                  onDragOver={(e) => {
                    e.preventDefault();
                    setIsDragging(true);
                  }}
                  onDragLeave={() => setIsDragging(false)}
                  onDrop={onDrop}
                  onClick={() => previewInputRef.current?.click()}
                  className={`border-2 border-dashed rounded-xl p-4 flex items-center gap-4 cursor-pointer transition-colors ${
                    isDragging
                      ? "border-[#E040FB] bg-[#E040FB]/5"
                      : "border-[#2A2D34] hover:border-[#E040FB]/50"
                  }`}
                >
                  {previewUrl ? (
                    <>
                      <img
                        src={previewUrl}
                        alt="Preview"
                        className="w-16 h-16 rounded-lg object-cover"
                      />
                      <div>
                        <p className="text-white text-sm font-medium">
                          Preview carregado
                        </p>
                        <p className="text-[#6B7280] text-xs">
                          Clique para substituir
                        </p>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="w-16 h-16 rounded-lg bg-[#111214] border border-[#2A2D34] flex items-center justify-center">
                        <Upload className="w-6 h-6 text-[#4B5563]" />
                      </div>
                      <div>
                        <p className="text-[#9CA3AF] text-sm">
                          Arraste ou clique para enviar
                        </p>
                        <p className="text-[#4B5563] text-xs">
                          PNG, WebP, GIF
                        </p>
                      </div>
                    </>
                  )}
                  <input
                    ref={previewInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) handleFileChange(f, "preview");
                    }}
                  />
                </div>
              </div>

              {/* Asset image upload */}
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs">
                  Asset Principal (frame, bubble, etc.)
                </Label>
                <div
                  onClick={() => assetInputRef.current?.click()}
                  className="border-2 border-dashed border-[#2A2D34] rounded-xl p-4 flex items-center gap-4 cursor-pointer hover:border-[#E040FB]/50 transition-colors"
                >
                  {assetUrl ? (
                    <>
                      <img
                        src={assetUrl}
                        alt="Asset"
                        className="w-16 h-16 rounded-lg object-cover"
                      />
                      <div>
                        <p className="text-white text-sm font-medium">
                          Asset carregado
                        </p>
                        <p className="text-[#6B7280] text-xs">
                          Clique para substituir
                        </p>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="w-16 h-16 rounded-lg bg-[#111214] border border-[#2A2D34] flex items-center justify-center">
                        <Upload className="w-6 h-6 text-[#4B5563]" />
                      </div>
                      <div>
                        <p className="text-[#9CA3AF] text-sm">
                          Arraste ou clique para enviar
                        </p>
                        <p className="text-[#4B5563] text-xs">
                          PNG, WebP, GIF, APNG
                        </p>
                      </div>
                    </>
                  )}
                  <input
                    ref={assetInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) handleFileChange(f, "asset");
                    }}
                  />
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-3 pt-2">
                <Button
                  type="button"
                  variant="ghost"
                  onClick={closeForm}
                  className="flex-1 border border-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-10"
                >
                  Cancelar
                </Button>
                <Button
                  type="submit"
                  disabled={submitting}
                  className="flex-1 bg-[#E040FB] hover:bg-[#D030EB] text-white h-10"
                >
                  {submitting ? (
                    <Loader2 className="w-4 h-4 animate-spin mr-2" />
                  ) : (
                    <Save className="w-4 h-4 mr-2" />
                  )}
                  {editingItem ? "Salvar Alterações" : "Criar Item"}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
