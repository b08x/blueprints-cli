// Blueprints CLI Web UI - Generator Page

document.addEventListener('DOMContentLoaded', function() {
    const generateButton = document.querySelector('button');
    const promptTextarea = document.querySelector('textarea');
    const languageSelect = document.querySelector('select:first-of-type');
    const frameworkSelect = document.querySelector('select:nth-of-type(2)');
    const styleSelect = document.querySelector('select:nth-of-type(3)');

    if (generateButton) {
        generateButton.addEventListener('click', handleGenerate);
    }

    async function handleGenerate(event) {
        event.preventDefault(); // Prevent form submission/page refresh
        
        const prompt = promptTextarea?.value?.trim();
        const language = getSelectValue(languageSelect);
        const framework = getSelectValue(frameworkSelect);
        const style = getSelectValue(styleSelect);

        if (!prompt) {
            alert('Please enter a prompt to generate code.');
            return;
        }

        try {
            // Show loading state
            generateButton.disabled = true;
            generateButton.textContent = 'Generating...';

            // Make API call
            const result = await window.app.generateCode(prompt, language, framework);
            
            // Display result
            displayGeneratedCode(result, { language, framework, style });
            
        } catch (error) {
            console.error('Code generation failed:', error);
            alert(`Code generation failed: ${error.message}`);
        } finally {
            // Reset button state
            generateButton.disabled = false;
            generateButton.textContent = 'Generate';
        }
    }

    function getSelectValue(selectElement) {
        if (!selectElement) return '';
        const selectedOption = selectElement.options[selectElement.selectedIndex];
        return selectedOption && selectedOption.value !== selectedOption.textContent ? selectedOption.value : selectedOption.textContent;
    }

    function displayGeneratedCode(result, options) {
        // Create a modal or new section to display the generated code
        const existingModal = document.querySelector('.code-modal');
        if (existingModal) {
            existingModal.remove();
        }

        const modal = document.createElement('div');
        modal.className = 'code-modal fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
        modal.innerHTML = `
            <div class="bg-[var(--surface-panels)] rounded-lg p-6 max-w-4xl max-h-[80vh] overflow-auto m-4">
                <div class="flex justify-between items-center mb-4">
                    <h3 class="text-2xl font-bold text-white">Generated Code</h3>
                    <button class="close-modal text-[var(--text-secondary)] hover:text-white">
                        <svg width="24" height="24" fill="currentColor" viewBox="0 0 256 256">
                            <path d="M205.66,194.34a8,8,0,0,1-11.32,11.32L128,139.31,61.66,205.66a8,8,0,0,1-11.32-11.32L116.69,128,50.34,61.66A8,8,0,0,1,61.66,50.34L128,116.69l66.34-66.35a8,8,0,0,1,11.32,11.32L139.31,128Z"></path>
                        </svg>
                    </button>
                </div>
                <div class="mb-4">
                    <p class="text-[var(--text-secondary)] text-sm">
                        Language: ${options.language || 'JavaScript'} • Framework: ${options.framework || 'React'} 
                        ${options.style ? ` • Style: ${options.style}` : ''}
                    </p>
                </div>
                <div class="bg-black bg-opacity-30 rounded-lg p-4 overflow-x-auto">
                    <pre><code class="text-[var(--text-light-gray)] font-mono text-sm">${escapeHtml(result.code || result)}</code></pre>
                </div>
                <div class="mt-6 flex justify-between">
                    <button class="copy-code px-4 py-2 bg-[var(--secondary-accent)] text-white rounded-lg hover:bg-opacity-80 transition-colors">
                        Copy Code
                    </button>
                    <button class="save-blueprint px-4 py-2 bg-[var(--primary-accent)] text-white rounded-lg hover:bg-opacity-80 transition-colors">
                        Save as Blueprint
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Add event listeners to modal buttons
        modal.querySelector('.close-modal').addEventListener('click', () => {
            modal.remove();
        });

        modal.querySelector('.copy-code').addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(result.code || result);
                const button = modal.querySelector('.copy-code');
                const originalText = button.textContent;
                button.textContent = 'Copied!';
                setTimeout(() => {
                    button.textContent = originalText;
                }, 2000);
            } catch (error) {
                console.error('Failed to copy code:', error);
            }
        });

        modal.querySelector('.save-blueprint').addEventListener('click', () => {
            // Navigate to submission page with the generated code
            const codeToSave = encodeURIComponent(result.code || result);
            window.location.href = `/submission?code=${codeToSave}`;
        });

        // Close modal when clicking outside
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.remove();
            }
        });
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text || '';
        return div.innerHTML;
    }

    // Handle navigation links to prevent page refresh
    document.querySelectorAll('a[href="#"]').forEach(link => {
        link.addEventListener('click', function(event) {
            event.preventDefault();
            
            const text = this.textContent.trim();
            switch (text) {
                case 'Search':
                    window.location.href = '/';
                    break;
                case 'Generate':
                    // Already on generator page
                    break;
                case 'Manage':
                    // TODO: Implement manage page
                    console.log('Manage page not yet implemented');
                    break;
                case 'Settings':
                    // TODO: Implement settings page
                    console.log('Settings page not yet implemented');
                    break;
                case 'Help':
                    // TODO: Implement help page
                    console.log('Help page not yet implemented');
                    break;
            }
        });
    });
});