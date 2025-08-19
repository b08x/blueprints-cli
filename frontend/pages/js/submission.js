// Blueprints CLI Web UI - Submission Page

document.addEventListener('DOMContentLoaded', function() {
    const codeTextarea = document.querySelector('textarea');
    const generateMetadataButton = document.querySelector('button[class*="primary-accent"]:first-of-type');
    const submitButton = document.querySelector('button[class*="primary-accent"]:last-of-type');
    const nameInput = document.getElementById('blueprint-name');
    const descriptionTextarea = document.getElementById('description');
    const categoriesInput = document.getElementById('categories');

    // Check if we have code from URL parameters (from generator page)
    const urlParams = new URLSearchParams(window.location.search);
    const prefilledCode = urlParams.get('code');
    if (prefilledCode && codeTextarea) {
        codeTextarea.value = decodeURIComponent(prefilledCode);
        // Auto-generate metadata for prefilled code
        setTimeout(() => handleGenerateMetadata({ preventDefault: () => {} }), 500);
    }

    if (generateMetadataButton) {
        generateMetadataButton.addEventListener('click', handleGenerateMetadata);
    }

    if (submitButton) {
        submitButton.addEventListener('click', handleSubmitBlueprint);
    }

    async function handleGenerateMetadata(event) {
        event.preventDefault();
        
        const code = codeTextarea?.value?.trim();
        
        if (!code) {
            alert('Please paste your code snippet first.');
            codeTextarea?.focus();
            return;
        }

        try {
            // Show loading state
            generateMetadataButton.disabled = true;
            generateMetadataButton.textContent = 'Generating...';

            // Make API call
            const metadata = await window.app.generateMetadata(code);
            
            // Fill in the form with generated metadata
            if (nameInput) nameInput.value = metadata.name || '';
            if (descriptionTextarea) descriptionTextarea.value = metadata.description || '';
            if (categoriesInput) {
                const categories = Array.isArray(metadata.categories) 
                    ? metadata.categories.join(', ') 
                    : metadata.categories || '';
                categoriesInput.value = categories;
            }

            // Show success message
            showSuccessMessage('Metadata generated successfully!');
            
        } catch (error) {
            console.error('Metadata generation failed:', error);
            showErrorMessage(`Metadata generation failed: ${error.message}`);
        } finally {
            // Reset button state
            generateMetadataButton.disabled = false;
            generateMetadataButton.textContent = 'Generate Metadata';
        }
    }

    async function handleSubmitBlueprint(event) {
        event.preventDefault();
        
        // Collect form data
        const formData = {
            name: nameInput?.value?.trim(),
            description: descriptionTextarea?.value?.trim(),
            code: codeTextarea?.value?.trim(),
            categories: categoriesInput?.value?.trim()
        };

        // Validate required fields
        if (!formData.code) {
            showErrorMessage('Please provide the code snippet.');
            codeTextarea?.focus();
            return;
        }

        if (!formData.name) {
            showErrorMessage('Please provide a blueprint name.');
            nameInput?.focus();
            return;
        }

        if (!formData.description) {
            showErrorMessage('Please provide a description.');
            descriptionTextarea?.focus();
            return;
        }

        try {
            // Show loading state
            submitButton.disabled = true;
            submitButton.textContent = 'Submitting...';

            // Process categories
            const categories = formData.categories 
                ? formData.categories.split(',').map(cat => cat.trim()).filter(cat => cat.length > 0)
                : [];

            // Prepare blueprint data
            const blueprintData = {
                name: formData.name,
                description: formData.description,
                code: formData.code,
                categories: categories,
                language: detectLanguage(formData.code),
                framework: detectFramework(formData.code)
            };

            // Submit to API
            const result = await window.app.createBlueprint(blueprintData);
            
            // Show success and redirect
            showSuccessMessage('Blueprint submitted successfully!');
            
            // Redirect to viewer page after a short delay
            setTimeout(() => {
                if (result.id) {
                    window.location.href = `/viewer?id=${result.id}`;
                } else {
                    window.location.href = '/';
                }
            }, 2000);
            
        } catch (error) {
            console.error('Blueprint submission failed:', error);
            showErrorMessage(`Blueprint submission failed: ${error.message}`);
            
            // Reset button state
            submitButton.disabled = false;
            submitButton.textContent = 'Submit Blueprint';
        }
    }

    function detectLanguage(code) {
        if (!code) return 'unknown';
        
        if (code.includes('function') || code.includes('=>') || code.includes('const') || code.includes('let')) {
            return 'javascript';
        }
        if (code.includes('def ') && (code.includes('import ') || code.includes('from '))) {
            return 'python';
        }
        if (code.includes('def ') && (code.includes('class ') || code.includes('require '))) {
            return 'ruby';
        }
        if (code.includes('<') && code.includes('>') && !code.includes('import')) {
            return 'html';
        }
        if (code.includes('{') && code.includes('}') && code.includes(':') && !code.includes('function')) {
            return 'css';
        }
        
        return 'text';
    }

    function detectFramework(code) {
        if (!code) return 'none';
        
        if (code.includes('React') || code.includes('jsx') || code.includes('useState')) {
            return 'react';
        }
        if (code.includes('<template>') || code.includes('Vue')) {
            return 'vue';
        }
        if (code.includes('@Component') || code.includes('Angular')) {
            return 'angular';
        }
        if (code.includes('Rails') || code.includes('ActiveRecord')) {
            return 'rails';
        }
        if (code.includes('Sinatra') || code.match(/get\s+['"]/)) {
            return 'sinatra';
        }
        
        return 'none';
    }

    function showSuccessMessage(message) {
        showMessage(message, 'success');
    }

    function showErrorMessage(message) {
        showMessage(message, 'error');
    }

    function showMessage(message, type) {
        // Remove existing message
        const existing = document.querySelector('.status-message');
        if (existing) existing.remove();

        // Create message element
        const messageEl = document.createElement('div');
        messageEl.className = `status-message fixed top-4 right-4 px-6 py-3 rounded-lg z-50 ${
            type === 'success' 
                ? 'bg-green-600 text-white' 
                : 'bg-red-600 text-white'
        }`;
        messageEl.textContent = message;

        document.body.appendChild(messageEl);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            messageEl.remove();
        }, 5000);
    }

    // Handle navigation links
    document.querySelectorAll('a[href="#"]').forEach(link => {
        link.addEventListener('click', function(event) {
            event.preventDefault();
            
            const text = this.textContent.trim();
            switch (text) {
                case 'Home':
                    window.location.href = '/';
                    break;
                case 'Submit Blueprint':
                    // Already on submission page
                    break;
                case 'Browse':
                    window.location.href = '/';
                    break;
                case 'Docs':
                    // TODO: Implement docs page
                    console.log('Docs page not yet implemented');
                    break;
            }
        });
    });

    // Auto-resize textareas
    const textareas = document.querySelectorAll('textarea');
    textareas.forEach(textarea => {
        textarea.addEventListener('input', function() {
            this.style.height = 'auto';
            this.style.height = this.scrollHeight + 'px';
        });
    });
});