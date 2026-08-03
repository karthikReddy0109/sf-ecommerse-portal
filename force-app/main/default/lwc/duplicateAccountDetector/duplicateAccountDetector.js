import { LightningElement, api, wire } from "lwc";
import findAccount from "@salesforce/apex/AccountController.findAccount";
import { FlowNavigationNextEvent } from "lightning/flowSupport";

export default class DuplicateAccountDetector extends LightningElement {
  @api companyName;
  @api availableActions = [];
  connectedCallback() {
    console.log("Company Name : ", this.companyName);
  }
  duplicateFound = false;
  proceedAnyway = false;
  errorMessage;
  @wire(findAccount, { accountName: "$companyName" })
  wiredDuplicate({ data, error }) {
    if (data) {
      this.duplicateFound = data.isSuccess && data.isDuplicate;
      this.proceedAnyway = false;
      this.errorMessage = this.duplicateFound ? "Duplicate Account found." : "";
    }
  }
  @api
  validate() {
    if (this.duplicateFound && !this.proceedAnyway) {
      return {
        isValid: false,
        errorMessage: this.errorMessage
      };
    }

    return {
      isValid: true
    };
  }

  handleProceedAnyway() {
    if (this.availableActions.includes("NEXT")) {
      this.proceedAnyway = true;
      this.dispatchEvent(new FlowNavigationNextEvent());
    }
  }
}
