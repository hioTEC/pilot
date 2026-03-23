# Shell functions for LLM model wrappers
# Sourced by setup.sh → .bashrc/.zshrc
# Keys come from .env (secrets.age → secrets env)

# Example: wrap Claude Code with an alternative model backend
# minimax() {
#   ANTHROPIC_BASE_URL=https://api.example.com/v1 \
#   ANTHROPIC_API_KEY="$MODEL_API_KEY" \
#   claude --model model-name --dangerously-skip-permissions "$@"
# }
