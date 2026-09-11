# Puma can serve each request in a thread from an internal thread pool.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# Bind to all interfaces so the container is reachable from Traefik.
port ENV.fetch("PORT") { 3000 }