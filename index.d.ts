export interface ShareData {
    documents?: [{url: string; mimeType: string;}];
    vcard?: {data: string; mimeType: string;}
    text?: {data: string; mimeType: string;}
    extraData?: object | undefined;
}

export type ShareCallback = (share?: ShareData) => void;

export interface ShareListener {
    remove(): void;
}

interface ShareMenu {
    getSharedText(callback: ShareCallback): void;
    getInitialShare(callback: ShareCallback): void;
    addNewShareListener(callback: ShareCallback): ShareListener;
    clearSharedText(): void;
}

interface ShareMenuReactView {
    dismissExtension(error?: string): void;
    openApp(): void;
    continueInApp(extraData?: object): void;
    data(): Promise<{mimeType: string, data: string}>;
}

export const ShareMenuReactView: ShareMenuReactView;
declare const ShareMenu: ShareMenu;
export default ShareMenu;