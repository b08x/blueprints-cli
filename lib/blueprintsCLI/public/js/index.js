// Blueprints CLI Web UI - Index Page

document.addEventListener('DOMContentLoaded', function() {
    const searchInput = document.getElementById('searchInput');
    const blueprintsGrid = document.getElementById('blueprintsGrid');

    // Load initial blueprints
    loadBlueprints();

    // Set up search functionality with debouncing
    const debouncedSearch = app.debounce(function(query) {
        loadBlueprints(query);
    }, 300);

    searchInput.addEventListener('input', function() {
        const query = this.value.trim();
        debouncedSearch(query);
    });

    // Handle blueprint card clicks
    blueprintsGrid.addEventListener('click', function(e) {
        const card = e.target.closest('.blueprint-card');
        if (card) {
            const blueprintId = card.dataset.id;
            if (blueprintId) {
                window.location.href = `/viewer?id=${blueprintId}`;
            }
        }
    });

    async function loadBlueprints(query = '') {
        try {
            app.showLoading(blueprintsGrid, 'Searching blueprints...');
            
            const blueprints = await app.getBlueprints(query);
            
            if (blueprints.length === 0) {
                blueprintsGrid.innerHTML = `
                    <div class="col-span-full text-center text-[var(--text-secondary)] py-8">
                        <svg class="mx-auto mb-4 h-12 w-12" fill="currentColor" viewBox="0 0 256 256">
                            <path d="M229.66,218.34l-50.07-50.06a88.11,88.11,0,1,0-11.31,11.31l50.06,50.07a8,8,0,0,0,11.32-11.32ZM40,112a72,72,0,1,1,72,72A72.08,72.08,0,0,1,40,112Z"></path>
                        </svg>
                        <p class="text-lg font-medium">No blueprints found</p>
                        <p class="mt-2">Try adjusting your search terms or create a new blueprint.</p>
                        <div class="mt-4">
                            <a href="/submission" class="btn-primary inline-block">Create Blueprint</a>
                        </div>
                    </div>
                `;
                return;
            }

            // Render blueprints
            blueprintsGrid.innerHTML = blueprints.map(blueprint => 
                app.createBlueprintCard(blueprint)
            ).join('');

        } catch (error) {
            console.error('Failed to load blueprints:', error);
            app.showError(blueprintsGrid, 'Failed to load blueprints. Please try again.');
        }
    }
});