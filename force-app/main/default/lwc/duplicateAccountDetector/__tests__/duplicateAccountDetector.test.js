import { createElement } from '@lwc/engine-dom';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import DuplicateAccountDetector from 'c/duplicateAccountDetector';
import findAccount from '@salesforce/apex/AccountController.findAccount';

const findAccountAdapter = registerApexTestWireAdapter(findAccount);

describe('c-duplicate-account-detector', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('shows Proceed Anyway and navigates to the next Flow screen', async () => {
        // Arrange
        const element = createElement('c-duplicate-account-detector', {
            is: DuplicateAccountDetector
        });

        // Act
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('lightning-button')).toBeNull();

        element.availableActions = ['NEXT'];
        findAccountAdapter.emit({ isSuccess: true, isDuplicate: true });
        await Promise.resolve();

        const button = element.shadowRoot.querySelector('lightning-button');
        expect(button).not.toBeNull();
        expect(button.label).toBe('Proceed Anyway');
        expect(element.validate()).toEqual({
            isValid: false,
            errorMessage: 'Duplicate Account found.'
        });

        const nextHandler = jest.fn();
        element.addEventListener('lightning__flownavigationnext', nextHandler);
        button.click();

        expect(nextHandler).toHaveBeenCalledTimes(1);
        expect(element.validate()).toEqual({ isValid: true });
    });
});
