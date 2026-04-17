#!/usr/bin/env node

/**
 * Script para gerar VAPID keys para Web Push Notifications
 * 
 * Uso:
 * node scripts/generate_vapid_keys.js
 * 
 * Saída:
 * - Exibe Public Key e Private Key
 * - Instruções para adicionar em Supabase Secrets
 */

const crypto = require('crypto');

function generateVAPIDKeys() {
  // Gerar par de chaves ECDP256
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
    publicKeyEncoding: {
      type: 'spki',
      format: 'pem'
    },
    privateKeyEncoding: {
      type: 'pkcs8',
      format: 'pem'
    }
  });

  // Converter para formato base64url (sem padding)
  function pemToBase64Url(pem) {
    // Remover header/footer PEM
    const base64 = pem
      .replace('-----BEGIN PUBLIC KEY-----', '')
      .replace('-----END PUBLIC KEY-----', '')
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\n/g, '');

    // Converter para base64url (sem padding)
    return base64
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }

  // Extrair coordenadas X e Y da chave pública
  function extractPublicKeyCoordinates(publicKeyPem) {
    const keyObj = crypto.createPublicKey({
      key: publicKeyPem,
      format: 'pem'
    });

    const keyDetails = keyObj.asymmetricKeyDetails;
    
    if (!keyDetails || keyDetails.namedCurve !== 'prime256v1') {
      throw new Error('Chave deve ser ECDP256');
    }

    // Obter coordenadas
    const publicKeyBuffer = keyObj.export({ format: 'der', type: 'spki' });
    
    // Extrair coordenadas (últimos 64 bytes para P-256)
    const coordinates = publicKeyBuffer.slice(-64);
    const x = coordinates.slice(0, 32);
    const y = coordinates.slice(32, 64);

    // Converter para base64url
    function toBase64Url(buffer) {
      return buffer
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
    }

    return toBase64Url(x) + toBase64Url(y);
  }

  const publicKeyBase64Url = extractPublicKeyCoordinates(publicKey);
  
  // Extrair private key em base64url
  const privateKeyObj = crypto.createPrivateKey({
    key: privateKey,
    format: 'pem'
  });
  
  const privateKeyDer = privateKeyObj.export({ format: 'der', type: 'pkcs8' });
  const privateKeyBase64Url = privateKeyDer
    .slice(-32) // Últimos 32 bytes são a chave privada
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

  return {
    publicKey: publicKeyBase64Url,
    privateKey: privateKeyBase64Url,
    publicKeyPem: publicKey,
    privateKeyPem: privateKey
  };
}

// Gerar keys
console.log('🔐 Gerando VAPID keys para Web Push Notifications...\n');

const keys = generateVAPIDKeys();

console.log('✅ VAPID Keys Geradas com Sucesso!\n');

console.log('📋 PUBLIC KEY (para o cliente Flutter Web):');
console.log('─'.repeat(80));
console.log(keys.publicKey);
console.log('─'.repeat(80));
console.log();

console.log('🔒 PRIVATE KEY (para Supabase Secrets):');
console.log('─'.repeat(80));
console.log(keys.privateKey);
console.log('─'.repeat(80));
console.log();

console.log('📝 INSTRUÇÕES PARA CONFIGURAR:\n');

console.log('1️⃣  Adicionar em Supabase Secrets:');
console.log('   - Nome: VAPID_PUBLIC_KEY');
console.log(`   - Valor: ${keys.publicKey}\n`);

console.log('2️⃣  Adicionar em Supabase Secrets:');
console.log('   - Nome: VAPID_PRIVATE_KEY');
console.log(`   - Valor: ${keys.privateKey}\n`);

console.log('3️⃣  Adicionar em Supabase Secrets:');
console.log('   - Nome: VAPID_SUBJECT');
console.log('   - Valor: mailto:seu-email@example.com\n');

console.log('4️⃣  Usar PUBLIC KEY em frontend/lib/core/services/web_push_service.dart:');
console.log(`   static const String _vapidPublicKey = '${keys.publicKey}';\n`);

console.log('5️⃣  Guardar PRIVATE KEY em local seguro (backup)');
console.log('   - Não compartilhar publicamente');
console.log('   - Usar apenas em Supabase Secrets\n');

console.log('✨ Pronto! As keys foram geradas com sucesso.');
console.log('   Próximo passo: Configurar em Supabase Dashboard\n');

// Exportar para arquivo JSON (opcional)
const fs = require('fs');
const keysFile = {
  publicKey: keys.publicKey,
  privateKey: keys.privateKey,
  generatedAt: new Date().toISOString(),
  warning: 'KEEP THIS FILE SECURE! Do not commit to version control!'
};

fs.writeFileSync('vapid_keys.json', JSON.stringify(keysFile, null, 2));
console.log('📁 Arquivo vapid_keys.json criado (adicionar ao .gitignore)');
