import { beforeEach, describe, expect, it, vi } from 'vitest';

// test/unit/onlineMusic/nativeQqNetwork.test.ts — 验证原生网络桥保留登录 Cookie、重定向和二进制图像。
const { plugin } = vi.hoisted(() => ({ plugin: { request: vi.fn(), cancel: vi.fn(), sessionSecret: vi.fn() } }));
vi.mock('@capacitor/core', () => ({
    registerPlugin: () => plugin,
    Capacitor: { getPlatform: () => 'ios' },
}));
import { nativeQqFetch } from '@/services/nativeQq/network';
import { getQqTransportAvailability, getQqRemoteApiBase } from '@/services/onlineMusic/qqTransport';

beforeEach(() => vi.clearAllMocks());
describe('Native QQ source runtime', () => {
    it('enables QQ without a remote backend URL', () => {
        vi.stubEnv('VITE_QQ_API_BASE', '');
        expect(getQqTransportAvailability()).toEqual({ configured: true });
        expect(getQqRemoteApiBase()).toBeNull();
        vi.unstubAllEnvs();
    });
    it('preserves redirect status and each login cookie for the source cookie jar', async () => {
        plugin.request.mockResolvedValue({ status: 302, headers: { location: 'https://y.qq.com/next' }, cookies: ['one=1', 'two=2'], body: '' });
        const response = await nativeQqFetch('https://open.weixin.qq.com/test', {
            redirect: 'manual', headers: { Cookie: 'old=1', 'User-Agent': 'okhttp/3.14.9' },
        });
        expect(response.status).toBe(302);
        expect(response.headers.getSetCookie()).toEqual(['one=1', 'two=2']);
        expect(plugin.request).toHaveBeenCalledWith(expect.objectContaining({ followRedirects: false, headers: expect.objectContaining({ cookie: 'old=1' }) }));
    });
    it('passes a JSON POST and returns image bytes without UTF-8 corruption', async () => {
        plugin.request.mockResolvedValue({ status: 200, headers: { 'content-type': 'image/png' }, cookies: [], body: 'AP8BAg==' });
        const response = await nativeQqFetch('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: 'POST', body: '{"key":"value"}' });
        expect([...new Uint8Array(await response.arrayBuffer())]).toEqual([0, 255, 1, 2]);
        expect(plugin.request.mock.calls[0][0].body).toBe(Buffer.from('{"key":"value"}').toString('base64'));
    });
    it('cancels the native task when the source request times out', async () => {
        plugin.request.mockReturnValue(new Promise(() => undefined));
        plugin.cancel.mockResolvedValue({});
        const controller = new AbortController();
        const pending = nativeQqFetch('https://u.y.qq.com/test', { signal: controller.signal });
        controller.abort(new DOMException('Timed out', 'TimeoutError'));
        await expect(pending).rejects.toMatchObject({ name: 'TimeoutError' });
        expect(plugin.cancel).toHaveBeenCalledWith({ id: expect.stringMatching(/^qq-/) });
    });
});
