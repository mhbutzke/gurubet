const { supabase } = require('../src/supabaseClient');

async function main() {
  try {
    const { data, error } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1 });
    if (error) {
      console.error('Erro ao conectar ao Supabase:', error.message);
      process.exit(1);
    }
    console.log('Conexão estabelecida com sucesso. Total de usuários:', data?.users?.length ?? 0);
  } catch (err) {
    console.error('Erro inesperado ao conectar com o Supabase:', err);
    process.exit(1);
  }
}

main();
