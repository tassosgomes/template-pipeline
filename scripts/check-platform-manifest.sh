#!/usr/bin/env bash
set -euo pipefail

manifest_path="${1:-platform.yml}"

if [[ $# -gt 1 ]]; then
  printf 'uso: %s [caminho-do-platform.yml]\n' "$0" >&2
  exit 2
fi

if [[ ! -f "$manifest_path" ]]; then
  printf 'manifesto não encontrado: %s\n' "$manifest_path" >&2
  exit 2
fi

if ! command -v ruby >/dev/null 2>&1; then
  printf 'Ruby é necessário para validar YAML/JSON sem dependências externas.\n' >&2
  exit 2
fi

exec ruby - "$manifest_path" <<'RUBY'
require "yaml"

manifest_path = ARGV.fetch(0)
stacks = %w[dotnet java go node python react-ts].freeze
criticalities = %w[baixa media alta critica].freeze
deploy_platforms = %w[vercel coolify aws azure gcp oci nenhum].freeze
environments = %w[dev staging prod].freeze
security_modes = %w[observe enforce].freeze
security_levels = %w[none critical high medium low].freeze
name_pattern = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/
path_pattern = /\A(?!\.?\z)(?!.*(?:\A|\/)\.\.?(?:\/|\z))[A-Za-z0-9_-][A-Za-z0-9._-]*(?:\/[A-Za-z0-9_-][A-Za-z0-9._-]*)*\z/

errors = []

def error(errors, location, message)
  errors << "#{location}: #{message}"
end

def hash_value(value, location, errors)
  unless value.is_a?(Hash)
    error(errors, location, "esperado objeto, recebido #{value.class}")
    return false
  end

  value.each_key do |key|
    error(errors, location, "chave deve ser texto: #{key.inspect}") unless key.is_a?(String)
  end
  true
end

def allowed_keys(value, allowed, location, errors)
  return unless value.is_a?(Hash)

  value.keys.reject { |key| allowed.include?(key) }.each do |key|
    error(errors, "#{location}.#{key}", "propriedade desconhecida")
  end
end

def required_keys(value, required, location, errors)
  required.each do |key|
    error(errors, "#{location}.#{key}", "propriedade obrigatória ausente") unless value.key?(key)
  end
end

def string_property(value, key, location, errors, max_length: nil, pattern: nil, enum: nil)
  return unless value.key?(key)

  current = value[key]
  unless current.is_a?(String)
    error(errors, "#{location}.#{key}", "esperado texto, recebido #{current.class}")
    return
  end

  error(errors, "#{location}.#{key}", "excede #{max_length} caracteres") if max_length && current.length > max_length
  error(errors, "#{location}.#{key}", "valor inválido #{current.inspect}") if pattern && !pattern.match?(current)
  error(errors, "#{location}.#{key}", "valor inválido #{current.inspect}; esperados: #{enum.join(', ')}") if enum && !enum.include?(current)
end

def boolean_property(value, key, location, errors)
  return unless value.key?(key)

  error(errors, "#{location}.#{key}", "esperado booleano, recebido #{value[key].class}") unless [true, false].include?(value[key])
end

def array_property(value, key, location, errors, allowed_values: nil, unique: false)
  return unless value.key?(key)

  current = value[key]
  unless current.is_a?(Array)
    error(errors, "#{location}.#{key}", "esperado array, recebido #{current.class}")
    return
  end

  current.each_with_index do |item, index|
    item_location = "#{location}.#{key}[#{index}]"
    unless item.is_a?(String)
      error(errors, item_location, "esperado texto, recebido #{item.class}")
      next
    end

    if allowed_values && !allowed_values.include?(item)
      error(errors, item_location, "valor inválido #{item.inspect}; esperados: #{allowed_values.join(', ')}")
    end
  end

  return unless unique

  current.each_with_index do |item, index|
    previous = current[0...index].index(item)
    error(errors, "#{location}.#{key}[#{index}]", "item duplicado #{item.inspect}") if previous
  end
end

def validate_deploy(value, location, errors, deploy_platforms, environments)
  return unless value.key?("deploy")
  deploy = value["deploy"]
  return unless hash_value(deploy, "#{location}.deploy", errors)

  allowed_keys(deploy, %w[plataforma ambientes], "#{location}.deploy", errors)
  string_property(deploy, "plataforma", "#{location}.deploy", errors, enum: deploy_platforms)
  array_property(deploy, "ambientes", "#{location}.deploy", errors, allowed_values: environments, unique: true)
end

def validate_security(value, location, errors, security_modes, security_levels)
  return unless value.key?("seguranca")
  security = value["seguranca"]
  return unless hash_value(security, "#{location}.seguranca", errors)

  allowed_keys(security, %w[modo reprovar-a-partir-de dast], "#{location}.seguranca", errors)
  string_property(security, "modo", "#{location}.seguranca", errors, enum: security_modes)
  string_property(security, "reprovar-a-partir-de", "#{location}.seguranca", errors, enum: security_levels)
  boolean_property(security, "dast", "#{location}.seguranca", errors)
end

def validate_contact(value, location, errors)
  return unless value.key?("contato")
  contact = value["contato"]
  return unless hash_value(contact, "#{location}.contato", errors)

  allowed_keys(contact, %w[slack email], "#{location}.contato", errors)
  string_property(contact, "slack", "#{location}.contato", errors)
  string_property(contact, "email", "#{location}.contato", errors, pattern: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
end

def validate_common(value, location, errors, stacks, criticalities, name_pattern, include_path: false, path_pattern: nil)
  allowed = %w[nome descricao time stack criticidade deploy seguranca contato]
  allowed << "path" if include_path
  allowed_keys(value, allowed, location, errors)

  string_property(value, "nome", location, errors, max_length: 63, pattern: name_pattern)
  string_property(value, "descricao", location, errors, max_length: 200)
  string_property(value, "time", location, errors)
  string_property(value, "stack", location, errors, enum: stacks)
  string_property(value, "criticidade", location, errors, enum: criticalities)
  string_property(value, "path", location, errors, max_length: 255, pattern: path_pattern) if include_path
  validate_deploy(value, location, errors, %w[vercel coolify aws azure gcp oci nenhum], %w[dev staging prod])
  validate_security(value, location, errors, %w[observe enforce], %w[none critical high medium low])
  validate_contact(value, location, errors)
end

def valid_string(value, key)
  value.is_a?(Hash) && value[key].is_a?(String)
end

begin
  content = File.read(manifest_path)
  manifest = YAML.safe_load(content, permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::Exception => e
  error(errors, manifest_path, "YAML/JSON inválido: #{e.message.lines.first.strip}")
  manifest = nil
rescue SystemCallError => e
  error(errors, manifest_path, "não foi possível ler o arquivo: #{e.message}")
  manifest = nil
end

kind = nil

if manifest.nil?
  error(errors, manifest_path, "manifesto vazio") unless errors.any? { |item| item.start_with?("#{manifest_path}: YAML/JSON inválido") }
elsif !manifest.is_a?(Hash)
  error(errors, manifest_path, "a raiz deve ser um objeto")
elsif manifest.key?("servicos")
  kind = "monorepo"
  required_keys(manifest, ["servicos"], "$", errors)
  allowed_keys(manifest, %w[defaults servicos], "$", errors)

  defaults = manifest["defaults"]
  if manifest.key?("defaults") && hash_value(defaults, "$.defaults", errors)
    allowed_keys(defaults, %w[time criticidade deploy seguranca contato], "$.defaults", errors)
    string_property(defaults, "time", "$.defaults", errors)
    string_property(defaults, "criticidade", "$.defaults", errors, enum: criticalities)
    validate_deploy(defaults, "$.defaults", errors, deploy_platforms, environments)
    validate_security(defaults, "$.defaults", errors, security_modes, security_levels)
    validate_contact(defaults, "$.defaults", errors)
  end

  services = manifest["servicos"]
  if !services.is_a?(Array)
    error(errors, "$.servicos", "esperado array, recebido #{services.class}")
    services = []
  elsif services.empty?
    error(errors, "$.servicos", "deve conter pelo menos um serviço")
  end

  names = {}
  paths = {}
  valid_paths = []

  services.each_with_index do |service, index|
    location = "$.servicos[#{index}]"
    unless hash_value(service, location, errors)
      next
    end

    required_keys(service, %w[nome path stack], location, errors)
    validate_common(service, location, errors, stacks, criticalities, name_pattern, include_path: true, path_pattern: path_pattern)

    if valid_string(service, "nome")
      if names.key?(service["nome"])
        error(errors, "#{location}.nome", "nome duplicado #{service["nome"].inspect}; já declarado em #{names[service["nome"]]}.nome")
      else
        names[service["nome"]] = location
      end
    end

    if valid_string(service, "path") && path_pattern.match?(service["path"])
      path = service["path"]
      if paths.key?(path)
        error(errors, "#{location}.path", "path duplicado #{path.inspect}; já declarado em #{paths[path]}.path")
      else
        paths[path] = location
      end
      valid_paths << [path, location]
    end

    unless valid_string(service, "time") || (defaults.is_a?(Hash) && defaults["time"].is_a?(String) && !defaults["time"].empty?)
      error(errors, "#{location}.time", "informe time no serviço ou defaults.time para definir o owner efetivo")
    end
  end

  valid_paths.each_with_index do |(path, location), index|
    valid_paths[0...index].each do |other_path, other_location|
      related = path == other_path || path.start_with?("#{other_path}/") || other_path.start_with?("#{path}/")
      next unless related
      next if path == other_path

      error(errors, "#{location}.path", "path #{path.inspect} sobrepõe #{other_path.inspect}, declarado em #{other_location}.path; paths de serviços não podem conter um ao outro")
    end
  end
else
  kind = "single-service"
  required_keys(manifest, %w[nome time stack], "$", errors)
  allowed_keys(manifest, %w[nome descricao time stack criticidade deploy seguranca contato], "$", errors)
  validate_common(manifest, "$", errors, stacks, criticalities, name_pattern)
end

if errors.empty?
  count = kind == "monorepo" ? "#{manifest["servicos"].length} serviço(s)" : "formato legado"
  puts "#{manifest_path}: manifesto válido (#{kind}, #{count})"
  exit 0
end

warn "#{manifest_path}: manifesto inválido"
errors.each { |message| warn "  - #{message}" }
exit 1
RUBY
